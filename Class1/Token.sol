//SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

contract DuggsToken {

    // token data
    string private constant _name = "MarksCoin";
    string private constant _symbol = "MarkCoin";
    uint8  private constant _decimals = 18;

    // total supply
    uint256 private _totalSupply = 1_000_000 * 10**_decimals;

    // balances
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    // Taxation on transfers
    uint256 public buyFee             = 100;
    uint256 public sellFee            = 200;
    uint256 public transferFee        = 100;
    uint256 public constant TAX_DENOM = 10000;

    // permissions
    struct Permissions {
        bool isFeeExempt;
        bool isLiquidityPool;
    }
    mapping ( address => Permissions ) public permissions;

    // Owner of contract
    address public owner;

    // Only Owner Modifier
    modifier onlyOwner() {
        require(msg.sender == owner, 'Only Owner');
        _;
    }

    // events
    event SetFeeExemption(address account, bool isFeeExempt);
    event SetAutomatedMarketMaker(address account, bool isMarketMaker);
    event SetFees(uint256 buyFee, uint256 sellFee, uint256 transferFee);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {

        // exempt sender for tax-free initial distribution
        permissions[msg.sender].isFeeExempt = true;

        // set owner
        owner = msg.sender;

        // initial supply allocation
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function totalSupply() external view returns (uint256) { 
        return _totalSupply; 
    }

    function balanceOf(address account) public view returns (uint256) { 
        return _balances[account]; 
    }

    function allowance(address holder, address spender) external view returns (uint256) { 
        return _allowances[holder][spender]; 
    }
    
    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function approve(address spender, uint256 amount) public  returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /** Transfer Function */
    function transfer(address recipient, uint256 amount) external  returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    /** Transfer Function */
    function transferFrom(address sender, address recipient, uint256 amount) external  returns (bool) {
        require(
            _allowances[sender][msg.sender] >= amount,
            'Insufficient Allowance'
        );
        _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;
        return _transferFrom(sender, recipient, amount);
    }

    function burn(uint256 amount) external returns (bool) {
        return _burn(msg.sender, amount);
    }

    /** Internal Transfer */
    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        require(
            recipient != address(0),
            'Zero Recipient'
        );
        require(
            amount > 0,
            'Zero Amount'
        );
        require(
            amount <= _balances[sender],
            'Insufficient Balance'
        );
        
        // decrement sender balance
        _balances[sender] = _balances[sender] - amount;

        // fee for transaction
        uint256 fee = getTax(sender, recipient, amount);

        // allocate fee
        if (fee > 0) {
            _totalSupply = _totalSupply - fee;
            emit Transfer(sender, address(0), fee);
        }

        // give amount to recipient
        uint256 sendAmount = amount - fee;
        _balances[recipient] = _balances[recipient] + sendAmount;

        // emit transfer
        emit Transfer(sender, recipient, sendAmount);
        return true;
    }

    function changeOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function registerAutomatedMarketMaker(address account) external onlyOwner {
        require(account != address(0), 'Zero Address');
        require(!permissions[account].isLiquidityPool, 'Already An AMM');
        permissions[account].isLiquidityPool = true;
        emit SetAutomatedMarketMaker(account, true);
    }

    function unRegisterAutomatedMarketMaker(address account) external onlyOwner {
        require(account != address(0), 'Zero Address');
        require(permissions[account].isLiquidityPool, 'Not An AMM');
        permissions[account].isLiquidityPool = false;
        emit SetAutomatedMarketMaker(account, false);
    }

    function setFees(uint _buyFee, uint _sellFee, uint _transferFee) external onlyOwner {
        require(
            _buyFee <= 2500,
            'Buy Fee Too High'
        );
        require(
            _sellFee <= 2500,
            'Sell Fee Too High'
        );
        require(
            _transferFee <= 2500,
            'Transfer Fee Too High'
        );

        buyFee = _buyFee;
        sellFee = _sellFee;
        transferFee = _transferFee;

        emit SetFees(_buyFee, _sellFee, _transferFee);
    }

    function setFeeExempt(address account, bool isExempt) external onlyOwner {
        require(account != address(0), 'Zero Address');
        permissions[account].isFeeExempt = isExempt;
        emit SetFeeExemption(account, isExempt);
    }

    function getTax(address sender, address recipient, uint256 amount) public view returns (uint256) {
        if ( permissions[sender].isFeeExempt || permissions[recipient].isFeeExempt ) {
            return (0);
        }
        return permissions[sender].isLiquidityPool ? 
               (amount * buyFee ) / TAX_DENOM : 
               permissions[recipient].isLiquidityPool ? 
               ( amount * sellFee ) / TAX_DENOM :
               ( amount * transferFee ) / TAX_DENOM;
    }

    function _burn(address account, uint256 amount) internal returns (bool) {
        require(
            account != address(0),
            'Zero Address'
        );
        require(
            amount > 0,
            'Zero Amount'
        );
        require(
            amount <= _balances[account],
            'Insufficient Balance'
        );
        _balances[account] = _balances[account] - amount;
        _totalSupply = _totalSupply - amount;
        emit Transfer(account, address(0), amount);
        return true;
    }
}