// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.5/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.5/contracts/token/ERC1155/ERC1155.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.5/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

/**
 * @dev {ERC1155} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter roles, 
 * as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 */
contract Founders is ERC1155Burnable, Ownable {

    /**
     * @dev mint tokens on deploy
     */
    constructor(string memory uri) ERC1155("https://gempire.io/{id}.json") {
        uint256[] storage ids;
        uint256[] storage amounts;
        ids.push(0);
        ids.push(1);
        ids.push(2);
        ids.push(3);
        amounts.push(1);
        amounts.push(8);
        amounts.push(89);
        amounts.push(987);
        _mintBatch(0x73B2A768dEe8f56177afE1212c7187C6aA21CED6, ids, amounts, "");
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}