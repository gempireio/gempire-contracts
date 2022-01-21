// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

// June 1992: Neal Stephenson coins the term Metaverse in his book Snow Crash. 
// June 2003: Linden Lab releases the Second Life virtual world. 
// October 2021: Facebook changes its name to Meta.

/**
 * @dev Interface of the BEP20 standard
 */
interface BEP20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IPancakePair {
    function sync() external;
}

contract GempireToken is BEP20 {
    /// @dev Token Details
    string public constant name = "Gempire.io";
    string public constant symbol = "GEMS";
    uint8 public constant decimals = 12;
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    uint256 private _totalSupply = 1618033988749894848204;
    uint256 public burnableSupply = 0;     // Amount that can be burned from liquidity pool
    uint256 public buys = 0;
    uint256 public sells = 0;
    uint256 public transfers = 0;

    /// @dev Divisors used to calculate fees/rewards
    uint64 public sellFeeDivisor = 25;   // Charged to sellers and sent to community pool
    uint64 public lpBurnDivisor = 4;       // Sold amount burnable from liquidity pool
    uint64 public buyMintDivisor = 100;  // Minted to community pool on each buy
    uint64 public burnRewardDivisor = 1000; // Reward for calling burnFromLp function

    /// @dev Addresses
    address public communityPool;
    mapping(address => bool) public admins;
    mapping(address => bool) public lpAddresses;

    constructor() {
        admins[msg.sender] = true;
        communityPool = msg.sender;
        balances[msg.sender] = _totalSupply;
    }

    /**
     * @dev Throws if called by any account other than an admin
     */
    modifier onlyAdmin() {
        require(admins[msg.sender], "GempireToken: caller is not Admin");
        _;
    }

    /**
     * @return uint256 the amount of tokens in existence.
     */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @return uint256 Balance of given @param account
     */
    function balanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return balances[account];
    }

    /**
     * @return uint256 Transfer allowance given to @param spender by @param owner
     */
    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return allowances[owner][spender];
    }

    /**
     * @notice Approves @param spender to spend up to @param amount on behalf of caller
     */
    function approve(address spender, uint256 amount)
        external
        override
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Increases the spending allowance granted to @param spender for caller by @param addedValue
     */
    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            allowances[msg.sender][spender] + addedValue
        );
        return true;
    }

    /**
     * @notice Decreases the spending allowance granted to @param spender for caller by @param subtractedValue
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        uint256 currentAllowance = allowances[msg.sender][spender];
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    /**
     * @param _newAdmin address to be added as Admin.
     */
    function setAdmin(address _newAdmin) external onlyAdmin {
        admins[_newAdmin] = true;
    }

    /**
     * @param _remove address to be removed as Admin.
     */
    function removeAdmin(address _remove) external onlyAdmin {
        admins[_remove] = false;
    }

    /**
     * @param _communityPool address that receives fees and newly minted tokens.
     */
    function setCommunityPool(address _communityPool) external onlyAdmin {
        communityPool = _communityPool;
    }

    /**
     * @param _sellFeeDivisor divisor to calculate fee charged to sellers
     */
    function setSellFeeDivisor(uint64 _sellFeeDivisor) external onlyAdmin {
        require(
            _sellFeeDivisor > 15,
            "GempireToken::setSellFeeDivisor: sellFeeDivisor must be greater than 15"
        ); // 1/16 = 6.25% max sell fee
        sellFeeDivisor = _sellFeeDivisor;
    }

    /**
     * @param _lpBurnDivisor divisor used to calculate amount that can be burned from liquidity pool per sale
     */
    function setLpBurnDivisor(uint64 _lpBurnDivisor) external onlyAdmin {
        lpBurnDivisor = _lpBurnDivisor;
    }

    /**
     * @param _buyMintDivisor divisor to calculate amount minted to community pool on each buy
     */
    function setBuyMintDivisor(uint64 _buyMintDivisor) external onlyAdmin {
        require(
            _buyMintDivisor > 3,
            "GempireToken::setBuyMintDivisor: setBuyMintDivisor must be greater than 3"
        ); // 1/4 = 25% max minting
        buyMintDivisor = _buyMintDivisor;
    }

    /**
     * @param _burnRewardDivisor divisor to calculate rewards given to caller of burnFromLP function
     */
    function setBurnRewardDivisor(uint64 _burnRewardDivisor) external onlyAdmin {
        require(
            _burnRewardDivisor > 49,
            "GempireToken::setBurnRewardDivisor: burnRewardDivisor must be greater than 49"
        ); // 1/50 = 2% max burn reward
        burnRewardDivisor = _burnRewardDivisor;
    }

    /**
     * @param _lpAddress address of liquidity pool to add
     */
    function addLiquidityPool(address _lpAddress) external onlyAdmin {
        IPancakePair lp = IPancakePair(_lpAddress);
        lp.sync();
        lpAddresses[_lpAddress] = true;
    }

    /**
     * @param _lpAddress address of liquidity pool to remove
     */
    function removeLiquidityPool(address _lpAddress) external onlyAdmin {
        lpAddresses[_lpAddress] = false;
    }

    /**
     * @notice Transfer tokens
     * @param recipient Address to receive transferred tokens
     * @param amount Amount to be sent. A portion may be collected as fees.
     */
    function transfer(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        require(
            recipient != address(0),
            "GempireToken::transfer: transfer to the zero address"
        );
        if ( lpAddresses[recipient] ) {
            // Sell. Add portion of sold tokens to burnable supply.
            _sellTransfer( msg.sender, recipient, amount);
        } else if ( lpAddresses[msg.sender] ) {
            // Buy. Mint new tokens to community pool.
            _buyTransfer( msg.sender, recipient, amount);
        } else {
            // Regular transfer.
            _transfer( msg.sender, recipient, amount);
        } 
        return true;
    }

    /**
     * @notice Transfer tokens from approved allowance
     * @param sender address sending tokens.
     * @param recipient address to receive transferred tokens.
     * @param amount Amount to be sent. A portion of this will be burned.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _approve(sender, msg.sender, allowances[sender][msg.sender] - amount);
        if ( lpAddresses[recipient] ) {
            // Sell. Increase burnable supply.
            _sellTransfer( sender, recipient, amount);
        } else if ( lpAddresses[sender] ) {
            // Buy. Mint to community pool.
            _buyTransfer( sender, recipient, amount);
        } else {
            // Regular transfer.
            _transfer( sender, recipient, amount);
        }   
        return true;
    }

    /**
     * @notice Transfers tokens to multiple addresses.
     * @param addresses Addresses to send tokens to.
     * @param amounts Amounts of tokens to send.
     */
    function multiTransfer(
        address[] calldata addresses,
        uint256[] calldata amounts
    ) external {
        require(
            addresses.length == amounts.length,
            "GempireToken::multiTransfer: addresses and amounts count do not match"
        );
        for (uint256 i = 0; i < amounts.length; i++) {
            _transfer(msg.sender, addresses[i], amounts[i]);
        }
    }

    /**
     * @notice Destroys @param amount tokens and reduces total supply.
     */
    function burn(uint256 amount) external {
        require(
            balances[msg.sender] >= amount,
            "GempireToken::burn: burn amount exceeds balance"
        );
        balances[msg.sender] -= amount;
        _totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    /**
     * @dev Moves @param amount tokens from @param sender to @param recipient without fees
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        require(
            recipient != address(0),
            "GempireToken::_transfer: transfer to the zero address"
        );
        balances[sender] -= amount;
        balances[recipient] += amount;
        transfers++;
        emit Transfer(sender, recipient, amount);
    }

    /**
     * @dev Moves @param amount tokens from @param sender to @param recipient and mints tokens to community pool
     */
    function _buyTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        uint256 mintAmount = amount / buyMintDivisor;
        balances[communityPool] += mintAmount;
        _totalSupply += mintAmount;
        balances[sender] -= amount;
        balances[recipient] += amount;
        buys++;
        emit Transfer(address(0), communityPool, mintAmount);
        emit Transfer(sender, recipient, amount);
    }

    /**
     * @dev Moves @param amount tokens from @param sender to @param recipient 
     * Send sell fee to community pool. Increase burnable supply.
     */
    function _sellTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        burnableSupply += amount / lpBurnDivisor;
        balances[sender] -= amount;
        uint256 sellFeeAmount = amount / sellFeeDivisor;
        balances[communityPool] += sellFeeAmount;   
        amount -= sellFeeAmount;  
        balances[recipient] += amount;
        sells++;
        emit Transfer(sender, communityPool, sellFeeAmount);
        emit Transfer(sender, recipient, amount);
    }

    /**
     * @notice Burns accumulated burnable supply from @param lpAddress. 
     * Send reward to @param rewardReceiver.
     */
    function burnFromLiquidityPool(address lpAddress, address rewardReceiver)
        external
    {
        require(
            lpAddresses[lpAddress],
            "GempireToken::burnFromLiquidityPool: lpAddress must be liquidity pool contract"
        );  
        // Burn no more than 10% of Liquidity Pool at a time
        if ( balances[lpAddress] / 10 < burnableSupply ) {
            burnableSupply = balances[lpAddress] / 10;
        } 
        uint256 reward = burnableSupply / burnRewardDivisor;
        balances[rewardReceiver] += reward;   
        balances[lpAddress] -= burnableSupply;
        _totalSupply -= burnableSupply - reward;     
        emit Transfer(address(0), rewardReceiver, reward);
        emit Transfer(lpAddress, address(0), burnableSupply);
        burnableSupply = 0;
        IPancakePair lp = IPancakePair(lpAddress);
        lp.sync();
    }

    /**
     * @notice Burns accumulated burnable supply multiplied by @param multiplier from @param lpAddress. 
     * Admin only. No reward.
     */
    function adminBurnFromLiquidityPool(address lpAddress, uint8 multiplier)
        external onlyAdmin
    {
        require(
            lpAddresses[lpAddress],
            "GempireToken::adminBurnFromLiquidityPool: lpAddress must be liquidity pool contract"
        );  
        require(
            multiplier < 5,
            "GempireToken::adminBurnFromLiquidityPool: multiplier must be less than 5"
        ); 
        burnableSupply *= multiplier;
        // Burn no more than 25% of Liquidity Pool at a time
        if ( balances[lpAddress] / 4 < burnableSupply ) {
            burnableSupply = balances[lpAddress] / 4;
        } 
        balances[lpAddress] -= burnableSupply;
        _totalSupply -= burnableSupply;     
        emit Transfer(lpAddress, address(0), burnableSupply);
        burnableSupply = 0;
        IPancakePair lp = IPancakePair(lpAddress);
        lp.sync();
    }


    /**
     * @notice Resets Burnable Supply Back to 0
     */
    function resetBurnableSupply() external onlyAdmin {
        burnableSupply = 0;
    }
    
    /**
     * @dev Approves spending to @param spender of up to @param amount tokens from @param owner
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

}

// 6296AC00