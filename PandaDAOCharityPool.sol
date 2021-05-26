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

// SPDX-License-Identifier: Unlicensed
contract PandaDAOCharityPool is Context,Ownable{
    
    using SafeMath for uint256;
    using Address for address;

    IERC20 private _pddToken;
    uint256 private _maxPercentageOfWithdraw = 10;
    uint256 private _lastWithdrawTime;
    //this is 7 days, uint is seconds
    uint256 private _withdrawTimeDelay = 604800;

    event Withdraw(address to);

    constructor (IERC20 token) public {
        _pddToken = token;
    }
    
    receive() external payable {}
    
    function totalCharityAmount() public view returns (uint256) {
        
        return _pddToken.balanceOf(address(this));
    }
    
    function getLastWithdrawTime() public view returns (uint256) {
        
        return _lastWithdrawTime;
    }
    
    function getWithdrawTimeDelay() public view returns (uint256) {
        
        return _withdrawTimeDelay;
    }

    
    function checkOtherTokenBalance(address tokenAddress) external view returns (uint256){
        
        require(tokenAddress != address(0),"Don't give me the 0 address!");
        require(tokenAddress.isContract(),"This is not contract address!");
        IERC20 token = IERC20(tokenAddress);
        return token.balanceOf(address(this));
    }
    
    function withdrawOtherToken(address tokenAddress,uint256 amount) external onlyOwner{
        
        require(tokenAddress != address(0),"Don't give me the 0 address!");
        require(tokenAddress.isContract(),"This is not contract address!");
        require(tokenAddress != address(_pddToken),"this method can't withdraw PDD Token!");
        require(amount > 0,"amount must > 0");
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount,"amount must < balance!");
        address to = _msgSender();
        token.transfer(to,amount);
        emit Withdraw(to);
    }
    
    function withdrawBNB(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount,"amount must  < balance!");
        require(amount > 0,"amount must > 0!");
        address payable to = _msgSender();
        to.transfer(amount);
        emit Withdraw(to);
    }
    
    function setMaxPercentageOfWithdraw(uint256 maxValue) external onlyOwner{
        _maxPercentageOfWithdraw = maxValue;
        address(this).balance;
    }

    function withdrawPDD(uint256 amount) external onlyOwner{
        require(
            amount <= totalCharityAmount().mul(_maxPercentageOfWithdraw).div(100),
            "The maximum amount exceeded!"
        );
        require(block.timestamp.sub(_lastWithdrawTime) >= _withdrawTimeDelay,"only withdraw once every 7 days");
        require(amount > 0,"amount must > 0!");
        address to = _msgSender();
        _pddToken.transfer(to,amount);
        _lastWithdrawTime = block.timestamp;
        emit Withdraw(to);
    }

}