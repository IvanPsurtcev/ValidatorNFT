// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Validator.sol";
import "../src/License.sol";
import "../src/RewardToken.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract ValidatorTest is Test {
    ValidatorContract validatorContract;
    License licenseToken;
    RewardToken rewardToken;

    address validator1 = address(0x1);
    address validator2 = address(0x2);
    address validator3 = address(0x3);

    uint256 constant EPOCH_DURATION = 3600; 
    uint256 constant INITIAL_REWARD = 100;

    uint256 startTimestamp;

    function setUp() public {
        licenseToken = new License();
        rewardToken = new RewardToken();
        validatorContract = new ValidatorContract(address(licenseToken), address(rewardToken), EPOCH_DURATION, INITIAL_REWARD);

        startTimestamp = block.timestamp;

        licenseToken.mint(validator1, 1);
        licenseToken.mint(validator2, 2);
        licenseToken.mint(validator2, 3);
        licenseToken.mint(validator3, 4);
        licenseToken.mint(validator3, 5);

        rewardToken.mint(address(validatorContract), 300 ether);

        vm.deal(validator1, 1 ether);
        vm.deal(validator2, 1 ether);
        vm.deal(validator3, 1 ether);
    }

    function testLockLicense() public {
        vm.startPrank(validator1);

        vm.expectRevert("Not the owner");
        validatorContract.lockLicense(2); 

        licenseToken.approve(address(validatorContract), 1);
        validatorContract.lockLicense(1);

        assertEq(licenseToken.ownerOf(1), address(validatorContract));
        vm.stopPrank();
    }

    function testUnlockLicenseAfterEpoch() public {
        vm.startPrank(validator1);
        licenseToken.approve(address(validatorContract), 1);
        validatorContract.lockLicense(1);

        vm.expectRevert("Epoch not passed");
        validatorContract.unlockLicense(1);

        assertEq(validatorContract.totalLockedLicenses(), 1);

        uint256 initialEpoch = validatorContract.currentEpoch();
        assertEq(initialEpoch, 0);

        vm.warp(block.timestamp + EPOCH_DURATION);

        uint256 newEpoch = validatorContract.currentEpoch();
        assertEq(newEpoch, initialEpoch + 1);

        validatorContract.unlockLicense(1);

        assertEq(validatorContract.totalLockedLicenses(), 0);
        assertEq(licenseToken.ownerOf(1), validator1);

        vm.expectRevert("License not locked");
        validatorContract.unlockLicense(1);

        vm.stopPrank();
    }

    function testClaimRewards() public {
        vm.startPrank(validator2);
        licenseToken.approve(address(validatorContract), 2);
        licenseToken.approve(address(validatorContract), 3);
        validatorContract.lockLicense(2);

        vm.expectRevert("Current epoch already processed");
        validatorContract.epochEnd();

        vm.expectRevert("No rewards to claim");
        validatorContract.claimRewards();

        vm.warp(block.timestamp + EPOCH_DURATION);
        validatorContract.epochEnd();

        uint256 rewardsBefore = rewardToken.balanceOf(validator2);
        uint256 contractBalanceBefore = rewardToken.balanceOf(address(validatorContract));
        validatorContract.claimRewards();
        uint256 rewardsAfter = rewardToken.balanceOf(validator2);
        uint256 contractBalanceAfter = rewardToken.balanceOf(address(validatorContract));

        assertGt(rewardsAfter, rewardsBefore); 
        assertEq(rewardsAfter - rewardsBefore, 100 ether); 
        assertEq(contractBalanceBefore - contractBalanceAfter, 100 ether);

        vm.warp(block.timestamp + EPOCH_DURATION);
        validatorContract.epochEnd();

        validatorContract.claimRewards();
        uint256 rewardsAfter2 = rewardToken.balanceOf(validator2);
        uint256 contractBalanceAfter2 = rewardToken.balanceOf(address(validatorContract));
        assertEq(rewardsAfter2 - rewardsAfter, 90 ether);
        assertEq(contractBalanceAfter - contractBalanceAfter2, 90 ether);

        validatorContract.lockLicense(3);
        address[] memory validators = validatorContract.getValidatorsList();
        assertEq(validators.length, 1);

        vm.stopPrank();
    }

    function testMultipleValidatorsRewards() public {
        vm.startPrank(validator1);
        licenseToken.approve(address(validatorContract), 1);
        validatorContract.lockLicense(1);
        vm.stopPrank();

        vm.startPrank(validator2);
        licenseToken.approve(address(validatorContract), 2);
        licenseToken.approve(address(validatorContract), 3);
        validatorContract.lockLicense(2);
        validatorContract.lockLicense(3);
        vm.stopPrank();

        vm.startPrank(validator3);
        licenseToken.approve(address(validatorContract), 4);
        licenseToken.approve(address(validatorContract), 5);
        validatorContract.lockLicense(4);
        validatorContract.lockLicense(5);
        vm.stopPrank();

        vm.warp(block.timestamp + EPOCH_DURATION);
        validatorContract.epochEnd();

        uint256 rewardsBeforeValidator1 = rewardToken.balanceOf(validator1);
        uint256 rewardsBeforeValidator2 = rewardToken.balanceOf(validator2);
        uint256 rewardsBeforeValidator3 = rewardToken.balanceOf(validator3);

        vm.startPrank(validator1);
        validatorContract.claimRewards();
        vm.stopPrank();

        vm.startPrank(validator2);
        validatorContract.claimRewards();
        vm.stopPrank();

        vm.startPrank(validator3);
        validatorContract.claimRewards();
        vm.stopPrank();

        uint256 rewardsAfterValidator1 = rewardToken.balanceOf(validator1);
        uint256 rewardsAfterValidator2 = rewardToken.balanceOf(validator2);
        uint256 rewardsAfterValidator3 = rewardToken.balanceOf(validator3);

        assertEq(rewardsAfterValidator1 - rewardsBeforeValidator1, uint256(100 ether) / 5); 
        assertEq(rewardsAfterValidator2 - rewardsBeforeValidator2, (uint256(100 ether) / 5) * 2); 
        assertEq(rewardsAfterValidator3 - rewardsBeforeValidator3, (uint256(100 ether) / 5) * 2); 

        vm.warp(block.timestamp + EPOCH_DURATION);
        validatorContract.epochEnd();

        vm.startPrank(validator1);
        validatorContract.claimRewards();
        vm.stopPrank();

        vm.startPrank(validator2);
        validatorContract.claimRewards();
        vm.stopPrank();

        vm.startPrank(validator3);
        validatorContract.claimRewards();
        vm.stopPrank();

        uint256 rewardsAfterValidator1_2 = rewardToken.balanceOf(validator1);
        uint256 rewardsAfterValidator2_2 = rewardToken.balanceOf(validator2);
        uint256 rewardsAfterValidator3_2 = rewardToken.balanceOf(validator3);

        assertEq(rewardsAfterValidator1_2 - rewardsAfterValidator1, (uint256(90 ether) / 5) * 1);
        assertEq(rewardsAfterValidator2_2 - rewardsAfterValidator2, (uint256(90 ether) / 5) * 2);
        assertEq(rewardsAfterValidator3_2 - rewardsAfterValidator3, (uint256(90 ether) / 5) * 2);

        vm.warp(block.timestamp + EPOCH_DURATION);
        validatorContract.epochEnd();

        vm.startPrank(validator1);
        validatorContract.claimRewards();
        vm.stopPrank(); 

        vm.startPrank(validator2);
        validatorContract.claimRewards();
        vm.stopPrank();

        vm.startPrank(validator3);
        validatorContract.claimRewards();
        vm.stopPrank();

        uint256 rewardsAfterValidator1_3 = rewardToken.balanceOf(validator1);
        uint256 rewardsAfterValidator2_3 = rewardToken.balanceOf(validator2);
        uint256 rewardsAfterValidator3_3 = rewardToken.balanceOf(validator3);

        assertEq(rewardsAfterValidator1_3 - rewardsAfterValidator1_2, (uint256(81 ether) / 5) * 1);
        assertEq(rewardsAfterValidator2_3 - rewardsAfterValidator2_2, (uint256(81 ether) / 5) * 2);
        assertEq(rewardsAfterValidator3_3 - rewardsAfterValidator3_2, (uint256(81 ether) / 5) * 2);

        vm.warp(block.timestamp + EPOCH_DURATION);
        validatorContract.epochEnd();  

        vm.startPrank(validator1);
        validatorContract.claimRewards();
        vm.stopPrank();

        vm.startPrank(validator2);
        vm.expectRevert("Not enough rewards in contract");
        validatorContract.claimRewards();
        vm.stopPrank();
    }
}
