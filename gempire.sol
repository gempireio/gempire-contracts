// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.2.0-solc-0.7/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.2.0-solc-0.7/contracts/token/ERC20/ERC20.sol";

contract Gempire is Ownable, ERC20 {

    using SafeMath for uint256;

    /// @notice Maximum supply allowed
    uint256 public constant maxSupply = 1000000e18;

    /// @notice Divisor for fraction of transferred funds that will be burned. 1/1000 = 0.1%
    uint256 public burnDivisor = 1000;

    /// @notice Address allowed to mint tokens
    address public minter = 0x73B2A768dEe8f56177afE1212c7187C6aA21CED6;

    /// @notice Whether free transfers should be allowed
    bool public allowFreeTransfer = true;

    constructor() ERC20("Gempire.io", "GEMS") {
        _mint(_msgSender(), 500000e18);
    }

    /**
     * @notice Set the burn divisor used to determine burn rate
     * @param _burnDivisor int used as divisor to calculate burn rate. total / divisor = burn_rate
     */
    function setBurnDivisor(uint256 _burnDivisor) external onlyOwner {
        require(_burnDivisor > 2, "Gempire::setBurnDivisor: burnDivisor must be greater than 2"); // 100 / 3 == 33.3% max burn
        burnDivisor = _burnDivisor;
    }

    /**
     * @notice Transfer and burn
     * @param recipient address to recieve transferred tokens
     * @param amount Amount to be sent. A portion of this will be burned.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 burnAmount = amount.div(burnDivisor);
        _burn(_msgSender(), burnAmount);
        return super.transfer(recipient, amount.sub(burnAmount));
    }

    /**
     * @notice Transfer and burn from approved allocation.
     * @param sender address sending tokens.
     * @param recipient address to recieve transferred tokens.
     * @param amount Amount to be sent. A portion of this will be burned.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 burnAmount = amount.div(burnDivisor);
        _burn(sender, burnAmount);
        return super.transferFrom(sender, recipient, amount.sub(burnAmount));
    }

    /**
     * @notice Transfer wihtout burn. This is not the standard ERC20 transfer.
     * @param recipient address to recieve transferred tokens.
     * @param amount Amount to be sent.
     */
    function freeTransfer(address recipient, uint256 amount) external returns (bool) {
        require(allowFreeTransfer, "Gempire::freeTransfer: freeTransfer is currently turned off");
        return super.transfer( recipient, amount);
    }

    /**
     * @notice Transfer from approved allocation. This is not the standard ERC20 transferFrom.
     * @param sender address sending tokens.
     * @param recipient address to recieve transferred tokens.
     * @param amount Amount to be sent.
     */
    function freeTransferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        require(allowFreeTransfer, "Gempire::freeTrasnfer: freeTrasnfer is currently turned off");
        return super.transferFrom(sender, recipient, amount);
    }

    /**
     * @param _allowFreeTransfer Whether free transfers should be allowed
     */
    function setAllowFreeTransfer(bool _allowFreeTransfer) external onlyOwner {
        allowFreeTransfer = _allowFreeTransfer;
    }

    /**
     * @param _minter address allowed to mint new tokens.
     */
    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
    }

    /**
     * @notice Mints new tokens. Can't cause supply to increase above maxSupply.
     * @param dst address to recive minted tokens.
     * @param amount Amount of new tokens to mint.
     */
    function mint(address dst, uint256 amount) external {      
        require( _msgSender() == minter , "Gempire::mint: only minter can mint tokens");
        require( super.totalSupply().add(amount) <= maxSupply , "Gempire::mint: can not mint more than max supply");
        require(dst != address(0), "Gempire::mint: cannot transfer to the zero address");
        _mint(dst, amount);
    }

    /**
     * @notice Burns (destroys) tokens and reduces total supply.
     * @param amount Amount of tokens to burn.
     */
    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    /**
     * @notice Burns (destroys) tokens from approved allocation and reduces total supply.
     * @param account address to burn from.
     * @param amount Amount of tokens to burn.
     */
    function burnFrom(address account, uint256 amount) external {
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount, "ERC20: burn amount exceeds allowance");

        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }

    /**
     * @notice Transfers tokens to multiple addresses.
     * @param addresses Addresses to send tokens to.
     * @param amounts Amounts of tokens to send.
     */
    function multiTransfer(address[] calldata addresses, uint256[] calldata amounts) external {
        require(addresses.length == amounts.length, "Gempire::multiTransfer: addresses and amounts count do not match");

        for (uint i = 0; i < amounts.length; i++) {
            super.transfer(addresses[i], amounts[i]);
        }
    }

    /**
     * @notice Mints new tokens to multiple addresses. Can't cause supply to increase above max supply.
     * @dev Check for max supply is done at end of function in order to save gas on valid mints that do not exceed max supply.
     * @dev In order to avoid wasted gas check sum of amounts before calling this function.
     * @param addresses addresses to receive minted tokens.
     * @param amounts Amounts of new tokens to mint.
     */
    function multiMint(address[] calldata addresses, uint256[] calldata amounts) external {
        require( _msgSender() == minter , "Gempire::multiMint: only minter can mint tokens");
        require(addresses.length == amounts.length, "Gempire::multiMint: addresses and amounts count do not match");

        uint256 totalMint = 0;
        for (uint i = 0; i < amounts.length; i++) {
            _mint(addresses[i], amounts[i]);
            totalMint += amounts[i];
        }

        // Check that minted tokens do not cause total supply to exceed max supply.
        require( totalSupply().add(totalMint) <= maxSupply  , "Gempire::multiMint: can not mint more than max supply");
    }

}