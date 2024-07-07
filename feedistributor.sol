/**
 *Submitted for verification at basescan.org on 2024-07-01
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function claimStuckTokens(address token) external;
    function excludeFromFees(address account, bool excluded) external;
    function changeFeeReceiver(address _feeReceiver) external;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

library Address {
    function sendValue(address payable recipient, uint256 amount) internal returns(bool){
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        return success; // always proceeds
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
        transferOwnership(0x77d9b33Ebd49c12E2FA83331092aC050DE2Fb3D2);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract WAGFeeDistributor is Ownable {
    using Address for address payable;

    struct Recipient {
        address recipient;
        uint256 weight;
    }

    IERC20 public WAGToken;
    Recipient[] public recipients;
    mapping(address => uint256) public recipientIndex;
    uint256 public totalWeight;
    uint256 public lastDistribution;
    uint256 public timeToDistribute;

    constructor () {   
        WAGToken = IERC20(0x0000000000000000000000000000000000000000);
        timeToDistribute = 7 days;
    }

    receive() external payable {
        if(block.timestamp > lastDistribution + timeToDistribute) {
            distributeETH();
            lastDistribution = block.timestamp;
        }
    }

    function creator() public pure returns (string memory) {
        return "t.me/coinsult_tg";
    }

    function changeWAGToken(address _token) external onlyOwner {
        WAGToken = IERC20(_token);
    }

    function setTimeToDistribute(uint256 _timeToDistribute) external onlyOwner {
        timeToDistribute = _timeToDistribute;
    }

    function claimStuckTokens(address token) external onlyOwner {
        if (token == address(0x0)) {
            payable(msg.sender).sendValue(address(this).balance);
            return;
        }
        
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    function claimStuckTokensOnWAG(address _token) external onlyOwner {
        WAGToken.claimStuckTokens(_token);
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner {
        WAGToken.excludeFromFees(account, excluded);
    }

    event FeeReceiverChanged(address feeReceiver);

    function changeFeeReceiver(address _feeReceiver) external onlyOwner {
        require(_feeReceiver != address(0), "CSLT: Fee receiver cannot be the zero address");
        WAGToken.changeFeeReceiver(_feeReceiver);
    }

    function addRecipient(address _recipient, uint256 _weight) external onlyOwner {
        require(recipientIndex[_recipient] == 0, "Recipient already added");
        recipients.push(Recipient({recipient: _recipient, weight: _weight}));
        recipientIndex[_recipient] = recipients.length; // Store index+1 to avoid zero value conflict
        totalWeight += _weight;
    }

    function removeRecipient(address _recipient) external onlyOwner {
        uint256 index = recipientIndex[_recipient];
        require(index > 0, "Recipient not found");

        uint256 idx = index - 1;
        totalWeight -= recipients[idx].weight;
        
        // Swap and pop
        recipients[idx] = recipients[recipients.length - 1];
        recipientIndex[recipients[idx].recipient] = index; // Update index mapping
        recipients.pop();
        
        delete recipientIndex[_recipient];
    }

    function resetRecipients() external onlyOwner {
        // Reset the total weight
        totalWeight = 0;

        // Clear the recipientIndex mapping
        for (uint256 i = 0; i < recipients.length; i++) {
            delete recipientIndex[recipients[i].recipient];
        }

        // Clear the recipients array
        delete recipients;
    }

    function distributeManual() external onlyOwner {
        distributeETH();
    }

    function distributeETH() internal {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to distribute");
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 share = (balance * recipients[i].weight) / totalWeight;
            payable(recipients[i].recipient).sendValue(share);
        }
    }
}
