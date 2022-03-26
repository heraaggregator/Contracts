// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract HeraAggregatorV1 is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    address private METIS = 0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000;
    address private ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    address payable feeRecipientAddress;
    address private feeContractAddress;

    address payable public manager;
    mapping(address => bool) public supportedRouters;
    mapping(address => mapping(bytes4 => bool)) public supportedSelectors;


    struct PathData {
        address tokenIn;
        address tokenOut;
        uint amountIn;
        uint amountOutMin;
        address router;
        bytes data;
    }

    event Swapped(
        address sender,
        address srcToken,
        address dstToken,
        uint256 spentAmount,
        uint256 returnAmount
    );

    constructor(address _feeContractAddress, address payable _feeRecipientAddress) payable {
        manager = payable(msg.sender);
        feeRecipientAddress = payable(_feeRecipientAddress);
        feeContractAddress = _feeContractAddress;
    }
    
    receive() external payable {}

    fallback() external payable {}

    function setFeeContractAddress(address _feeContractAddress) public onlyOwner{
        feeContractAddress = _feeContractAddress;
    }

    function setFeeRecipientAddress(address payable _feeRecipientAddress) public onlyOwner{
        feeRecipientAddress = _feeRecipientAddress;
    }

    function transferfee(address payable _to, uint _amount) private {
        uint amount = address(this).balance;
        uint feeAmount = _amount;
        if(amount >= _amount)
            feeAmount = amount;
            
        (bool success, ) = _to.call{value: feeAmount}("");
        require(success, "Failed to send Metis");
    }

    function transferfeetoken(address _to, uint _amount, address _tokenIn) private {
        uint amount = IERC20(_tokenIn).balanceOf(address(this));
        uint feeAmount = _amount;
        if(amount >= _amount)
            feeAmount = amount;
        SafeERC20.safeTransfer(IERC20(_tokenIn), _to, feeAmount);
    }

    function transfer(address payable _to, uint _amount) private {
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Failed to send Metis");
    }

    function rescueFunds(IERC20 token, uint256 amount) external onlyOwner {
        token.transfer(msg.sender, amount);
    }

    function destroy() external onlyOwner {
        selfdestruct(payable(msg.sender));
    }

    function setAvailableRouter(bool available, address router)
        public
        onlyOwner
    {
        supportedRouters[router] = available;
    }

    function setRouterSelector(
        bytes4 selector,
        address router,
        bool available
    ) public onlyOwner {
        supportedSelectors[router][selector] = available;
    }

    function swap(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOut, PathData[] calldata paths) external payable nonReentrant{
        require(_amountOut > 0, "Min return should not be 0");
        require(paths.length > 0, "Path should not be empty");

        if(_tokenIn != METIS)
            SafeERC20.safeTransferFrom(IERC20(_tokenIn),msg.sender, address(this), _amountIn);
        
        for(uint256 i; i < paths.length; i++){
            require(supportedRouters[paths[i].router], "UNSUPPORTED_ROUTER");
            require(supportedSelectors[paths[i].router][bytes4(paths[i].data)],"UNSUPPORTED_SELECTOR");
            bool success;
            bytes memory result;
            if(METIS == paths[i].tokenIn){
                (success,result) = address(paths[i].router).call{value: paths[i].amountIn}(paths[i].data);
            }
            else {
                SafeERC20.safeApprove(IERC20(paths[i].tokenIn), address(paths[i].router), paths[i].amountIn);
                (success,result) = payable(paths[i].router).call(paths[i].data);
            }
            require(success, "SWAP_FAILED");
        }
        if(_tokenOut == METIS)
            transfer(payable(msg.sender), _amountOut);
        else
            SafeERC20.safeTransfer(IERC20(_tokenOut), msg.sender, _amountOut);
        
        IFeeCalled feecall = IFeeCalled(feeContractAddress);
        (uint256 fee, uint256 feeDivider) = feecall.getFee(msg.sender);
        require(fee <= 100 && feeDivider == 10000, "FEE_HIGH");
        uint256 feeAmount = _amountIn.mul(fee).div(feeDivider);
        if (feeAmount > 0) {
            if(_tokenIn == METIS)
                transferfee(feeRecipientAddress, feeAmount);
            else
                transferfeetoken(feeRecipientAddress, feeAmount, _tokenIn);
        }

        emit Swapped(
            msg.sender,
            _tokenIn,
            _tokenOut,
            _amountIn,
            _amountOut
        );

    }
    
    

}

interface IFeeCalled{
    function getFee(address recipient) external returns (uint256, uint256);
}
