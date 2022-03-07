// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract HeraFeeOrganizer is Ownable, ReentrancyGuard {

    uint256 maxFee = 100;
    uint256 maxFeeDivider = 10000;
    uint256 defaultFee = 30;
    uint256 defaultFeeDivider = 10000;

    function setDefaultFee(uint256 _fee, uint256 _feeDivider) public onlyOwner{
        require(_fee <= maxFee,"Than Max Fee");
        require(_feeDivider <= maxFeeDivider,"Than Max Fee Divider");
        defaultFee = _fee;
        defaultFeeDivider = _feeDivider;
    }

    function getFee(address recipient) public view returns (uint256, uint256){
        uint256 fee = defaultFee;
        uint256 feeDivider = defaultFeeDivider;
        return (fee,feeDivider);
    }


}
