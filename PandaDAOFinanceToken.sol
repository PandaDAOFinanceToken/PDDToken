
/*

PandaDAOFinance is a Crypto Charity Fund!
Every Transaction You Change The World!

telegram: https://t.me/PandaDaoToken
websit: www.pandadao.finance

PandaDAO Ecosystem:
   1% will be converted into a locked LP
   0.5% into a charity fund account
   0.5% will be destroyed
*/


pragma solidity 0.6.12;

import "./Library.sol";
import "./Pancakeswap.sol";


// SPDX-License-Identifier: Unlicensed
contract PandaDAOFinanceToken is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;
    
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;
   
    uint256 private constant _tTotal = 100 * 10**6 * 10**18;
    uint256 private  _tFeeTotal;

    string private constant _name = "PandaDAO Finance Token";
    string private constant _symbol = "PDD";
    uint8 private constant _decimals = 18;
    //1%
    uint256 public _liquidityFee = 1;
    uint256 private _previousLiquidityFee = _liquidityFee;
    //0.5%
    uint256 public _burnFee = 5;
    uint256 private _previousBurnFee = _burnFee;
    //0.5%
    uint256 public _charityPoolFee = 5;
    address public _charityPoollAddress;
    uint256 private _previousCharityPoolFee = _charityPoolFee;

    IPancakeRouter02 public immutable pancakeRouter;
    address public immutable pancakePair;
    
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    address public _lplockedPoolAddress;

    uint256 private constant numTokensSellToAddToLiquidity = 5000 * 10**18;
    
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    constructor () public {
        _tOwned[_msgSender()] = _tTotal;
        //Mochiswap Router (BSC MainNet)0x939ffC5a4f3e9DF85e1036A8C86b18599A403F3B
        IPancakeRouter02 _pancakeRouter = IPancakeRouter02(0x939ffC5a4f3e9DF85e1036A8C86b18599A403F3B);
         // Create a pancakeswap pair for this new token
        pancakePair = IPancakeFactory(_pancakeRouter.factory())
            .createPair(address(this), _pancakeRouter.WETH());

        // set the rest of the contract variables
        pancakeRouter = _pancakeRouter;
        
        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_charityPoollAddress] = true;
        _isExcludedFromFee[address(0)] = true;
        
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() external pure returns (string memory) {
        return _name;
    }

    function symbol() external pure returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _tOwned[account];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }


    function totalFees() external view returns (uint256) {
        return _tFeeTotal;
    }
    
     //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _getRValues(uint256 tAmount, uint256 currentRate) private pure returns (uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        return (rAmount);
    }
    
    function _takeLiquidity(uint256 tLiquidity) private {
        _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }
    


    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liquidityFee).div(
            10**2
        );
    }
    
    function removeAllFee() private {
        
        _liquidityFee = 0;
        _burnFee = 0;
        _charityPoolFee = 0;
    }
    
    function restoreAllFee() private {
        
        _liquidityFee = 1;
        _burnFee = 5;
        _charityPoolFee = 5;
    }
    
    function isExcludedFromFee(address account) external view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this)); 
      
        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != pancakePair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }
        
        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeRouter.WETH();

        _approve(address(this), address(pancakeRouter), tokenAmount);

        // make the swap
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pancakeRouter), tokenAmount);
        if(_lplockedPoolAddress == address(0)){
            _lplockedPoolAddress = owner();
        }
        // add the liquidity
        pancakeRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            _lplockedPoolAddress,
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount) private {
        if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]){
            removeAllFee();
        }
        
        //Calculate burn amount and charity fund amount
        uint256 burnAmt = amount.mul(_burnFee).div(10**3);
        uint256 charityAmt = amount.mul(_charityPoolFee).div(10**3);
        uint256 liquidity = calculateLiquidityFee(amount);


        _transferStandard(sender, recipient, amount.sub(burnAmt).sub(charityAmt).sub(liquidity),liquidity);
        //Temporarily remove fees to transfer to burn address and chairty wallet
        _liquidityFee = 0;
        
        if(burnAmt > 0){
            _transferStandard(sender, address(0), burnAmt,0);
        }
        if(charityAmt > 0){
            _transferStandard(sender, _charityPoollAddress, charityAmt,0);
        }
        //Restore liquidity fees
        _liquidityFee = _previousLiquidityFee;


        if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient])
            restoreAllFee();
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount, uint256 tLiquidity) private {
        
        _tOwned[sender] = _tOwned[sender].sub(tAmount).sub(tLiquidity);
        _tOwned[recipient] = _tOwned[recipient].add(tAmount);
        _takeLiquidity(tLiquidity);
        emit Transfer(sender, recipient, tAmount);
    }

    function excludeFromFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = true;
    }
    
    function includeInFee(address account) external onlyOwner {
        _isExcludedFromFee[account] = false;
    }
    function setCharityPoolAddress(address poolAddress) external onlyOwner {
        _charityPoollAddress = poolAddress;
        _isExcludedFromFee[_charityPoollAddress] = true;
    }
    function setLPLockedPoolAddress(address poolAddress) external onlyOwner {
        _lplockedPoolAddress = poolAddress;
        _isExcludedFromFee[_lplockedPoolAddress] = true;
    }
    
   
    function enableAllFees() external onlyOwner() {
        
        _liquidityFee = 1;
        _previousLiquidityFee = _liquidityFee;
        _burnFee = 5;
        _charityPoolFee = 5;
        _previousCharityPoolFee = _charityPoolFee;
        inSwapAndLiquify = true;
        emit SwapAndLiquifyEnabledUpdated(true);
    }

    function disableAllFees() external onlyOwner() {
        _liquidityFee = 0;
        _previousLiquidityFee = _liquidityFee;
        _burnFee = 0;
        _charityPoolFee = 0;
        _previousCharityPoolFee = _charityPoolFee;
        inSwapAndLiquify = false;
        emit SwapAndLiquifyEnabledUpdated(false);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
    
}