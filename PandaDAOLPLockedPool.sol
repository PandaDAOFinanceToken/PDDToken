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
contract PandaDAOLPLockedPool is Context,Ownable {
    
    using SafeMath for uint256;
    using Address for address;

    IERC20 private _LPtoken;
    //unlock time
    uint256 public _unLockBlockTime;
    // total locked time unit seconds this is 1 years
    uint256  public constant _totalLockedBlockTime = 31536000;
    
    constructor () public {
        _unLockBlockTime = block.timestamp.add(_totalLockedBlockTime);
    }
    
    function setLPTokenAddress(address token) external onlyOwner{
        _LPtoken = IERC20(token);
    }
    
    function getTotalLockedLP() external view returns (uint256){
        return _LPtoken.balanceOf(address(this));
    }
    
    function currentBlockTime() external view returns (uint256) {
        return block.timestamp;
    }
    
    function addOneYearLockedBlock() external onlyOwner {
        _unLockBlockTime = block.timestamp.add(_totalLockedBlockTime);
    }
    
    function withdrawAllLP() external onlyOwner {
        uint256 amount = _LPtoken.balanceOf(address(this));
        require(block.timestamp >= _unLockBlockTime,"The current time less than unlock block number!");
        require(amount > 0,"The lp balance less than  0!");
        address to = _msgSender();
        _LPtoken.transfer(to,amount);
    }
}