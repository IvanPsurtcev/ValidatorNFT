// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract License is ERC721 {
    constructor() ERC721("License", "LS") {}

    function mint(address to, uint256 value) external {
        _mint(to, value);
    }
}