// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./RewardToken.sol";
import "forge-std/console.sol";

contract ValidatorContract {
    IERC721 public licenseToken;
    RewardToken public rewardToken;

    uint256 public startTimestamp;
    uint256 public epochDuration;
    uint256 public currentRewardPerEpoch;

    uint256 public totalLockedLicenses;
    uint256 public lastProcessedEpoch;

    struct Validator {
        uint256[] lockedLicenses;
        uint256 rewards;
        bool isInValidatorsList;
        mapping(uint256 => uint256) lockTimestamps;
    }

    mapping(address => Validator) public validators;
    address[] private validatorsList;

    event LicenseLocked(address indexed validator, uint256 tokenId);
    event LicenseUnlocked(address indexed validator, uint256 tokenId);
    event RewardsClaimed(address indexed validator, uint256 amount);
    event EpochEnded(uint256 newEpoch, uint256 newReward);

    constructor(address _licenseToken, address _rewardToken, uint256 _epochDuration, uint256 _initialReward) {
        licenseToken = IERC721(_licenseToken);
        rewardToken = RewardToken(_rewardToken);
        epochDuration = _epochDuration;
        currentRewardPerEpoch = _initialReward;
        startTimestamp = block.timestamp;
    }

    function currentEpoch() public view returns (uint256) {
        return (block.timestamp - startTimestamp) / epochDuration;
    }

    function getValidatorsList() external view returns (address[] memory) {
        return validatorsList;
    }

    function lockLicense(uint256 tokenId) external {
        require(licenseToken.ownerOf(tokenId) == msg.sender, "Not the owner");

        licenseToken.transferFrom(msg.sender, address(this), tokenId);

        Validator storage validator = validators[msg.sender];
        validator.lockedLicenses.push(tokenId);
        validator.lockTimestamps[tokenId] = block.timestamp;

        
        if (!validator.isInValidatorsList) {
            validatorsList.push(msg.sender);
            validator.isInValidatorsList = true;
        }

        totalLockedLicenses += 1;

        emit LicenseLocked(msg.sender, tokenId);
    }

    function unlockLicense(uint256 tokenId) external {
        uint256 lockEpoch = (block.timestamp - validators[msg.sender].lockTimestamps[tokenId]) / epochDuration;
        require(lockEpoch > 0, "Epoch not passed");
        require(isLicenseLocked(msg.sender, tokenId), "License not locked");

        Validator storage validator = validators[msg.sender];

        removeLockedLicense(validator, tokenId);

        totalLockedLicenses -= 1;

        licenseToken.transferFrom(address(this), msg.sender, tokenId);

        emit LicenseUnlocked(msg.sender, tokenId);
    }

    function claimRewards() external {
        Validator storage validator = validators[msg.sender];
        require(validator.rewards > 0, "No rewards to claim");
        require(rewardToken.balanceOf(address(this)) >= validator.rewards, "Not enough rewards in contract");

        uint256 rewards = validator.rewards;
        validator.rewards = 0;

        rewardToken.transfer(msg.sender, rewards);

        emit RewardsClaimed(msg.sender, rewards);
    }

    function epochEnd() external {
        require(currentEpoch() > lastProcessedEpoch, "Current epoch already processed");
        lastProcessedEpoch = currentEpoch();

        distributeRewards();
        currentRewardPerEpoch = (currentRewardPerEpoch * 90) / 100;

        emit EpochEnded(lastProcessedEpoch, currentRewardPerEpoch);
    }

    function distributeRewards() private {
        console.log("validatorsList.length", validatorsList.length);
        if (totalLockedLicenses > 0) {
            for (uint256 i = 0; i < validatorsList.length; i++) {
                address validator = validatorsList[i];
                uint256 licenses = validators[validator].lockedLicenses.length;
                console.log("validator", validator);
                console.log("licenses", licenses);

                if (licenses > 0) {
                    uint256 reward = currentRewardPerEpoch * licenses * 10**18 / totalLockedLicenses;
                    console.log("reward", reward);
                    console.log("currentRewardPerEpoch", currentRewardPerEpoch);
                    console.log("licenses", licenses);
                    console.log("totalLockedLicenses", totalLockedLicenses);
                    validators[validator].rewards += reward;
                }
            }
        }
    }

    function isLicenseLocked(address validator, uint256 tokenId) private view returns (bool) {
        uint256[] storage lockedLicenses = validators[validator].lockedLicenses;
        for (uint256 i = 0; i < lockedLicenses.length; i++) {
            if (lockedLicenses[i] == tokenId) {
                return true;
            }
        }
        return false;
    }

    function removeLockedLicense(Validator storage validator, uint256 tokenId) private {
        uint256[] storage lockedLicenses = validator.lockedLicenses;
        uint256 length = lockedLicenses.length;
        for (uint256 i = 0; i < length; i++) {
            if (lockedLicenses[i] == tokenId) { 
                lockedLicenses[i] = lockedLicenses[length - 1];
                lockedLicenses.pop();
                return;
            }
        }
    }
}
