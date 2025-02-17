// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import {Token} from "./Token.sol";


error ListingFeerequired();
error InsufficientFunds();
error SaleIsClosed();
error AmountToLow();
error AmountToHigh();
error TargetNotReached();
error NotAuthorized();

contract FactoryContract {
    uint256 public constant TARGET = 3 ether;
    uint256 private constant TARGET_LIMIT = 500_000 ether;

    uint256 public immutable listingFee;
    address public owner;

    
    address[] public tokens; //array of created tokens
    uint256 public totalTokens;
    mapping(address => TokenSale) public tokenToSale;

    struct TokenSale {
        address token;
        string name;
        string desciption;
        address creator;
        uint256 sold;
        uint256 raised;
        bool isOpen;
    }

    event Created(address indexed token);
    event Buy(address indexed token, uint256 amount);
    event TokenListed(address indexed token, string name, string description, address indexed owner);

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotAuthorized();
        }
        _;
    }

    modifier nonReentrant {
        require(!locked, "Reentrancy attempt");
        locked = true;
        _;
        
        locked = false;
    }

    constructor(uint256 _listingFee) {
        listingFee = _listingFee;
        owner = msg.sender;
    }

    function createToken(
        string memory _name,
        string memory _symbol,
        string memory _description
    ) public payable {

        if (msg.value <= 0) {
            revert ListingFeerequired();
        }
        //Allow creation of tokens through token instanciation
        Token token = new Token(_name, _symbol, 1_000_000 ether);

        tokens.push(address(token)); //pushing each created tokens in an array for saving.

        totalTokens++; //get token amount

        //list the tokens for sale
        TokenSale memory sale = TokenSale(
            address(token),
            _name,
            _description,
            msg.sender,
            0,
            0,
            true
        );

        tokenToSale[address(token)] = sale;

        emit Created(address(token));
        emit TokenListed(address(token), _name, _description, OWNER);
    }

    function buyToken(address _token, uint256 _amount) external payable nonReentrant {
        // require(msg.value >= _amount, "Insufficient funds");
        TokenSale storage sale = tokenToSale[_token];

        if (sale.isOpen != true) {
            revert SaleIsClosed();
        }

        if (_amount < 1 ether) {
            revert AmountToLow();
        }

        if (_amount > 10000 ether) {
            revert AmountToHigh();
        }

        uint256 cost = getCostPrice(sale.sold);

        uint256 price = cost * (_amount / (10 ** 18));

        if (msg.value < price) {
            revert InsufficientFunds();
        }

        sale.sold += _amount;
        sale.raised += price;

        if (sale.sold >= TARGET_LIMIT || sale.raised >= TARGET) {
            sale.isOpen = false;
        }

        Token(_token).transfer(msg.sender, _amount);

        emit Buy(_token, _amount);
    }

    function DepositToken(address _token, string memory _name, string memory _symbol) public nonReentrant {
        Token token = new Token(_name, _symbol, 1_000_000 ether);
        TokenSale memory sale = tokenToSale[_token];

        if (sale.isOpen != true) {
            revert TargetNotReached();
        }

        token.transfer(sale.creator, token.balanceOf(address(this)));

        (bool success, ) = payable(sale.creator).call{value: sale.raised}("");
        require(success, "ETH transfer failed");
    }

    function WithdrawToken(uint256 _amount) public onlyOwner nonReentrant {
        (bool success, ) = payable(owner).call{value: _amount}("");
        require(success, "ETH transfer failed");
    }

    function getTokenSale(
        uint256 _index
    ) public view returns (TokenSale memory) {
        return tokenToSale[tokens[_index]];
    }

    function getCostPrice(uint256 _sold) public pure returns (uint256) {
        uint256 floor = 0.0001 ether;
        uint256 step = 0.0001 ether;
        uint256 increment = 10000 ether;

        uint256 cost = (step * (_sold / increment)) + floor;
        return cost;
    }
    
}
