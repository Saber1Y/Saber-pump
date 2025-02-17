// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import {Token} from "./Token.sol";


// Custom error declarations
error ListingFeerequired();  // Error for when the listing fee isn't provided or is incorrect
error InsufficientFunds();  // Error for insufficient funds when buying tokens
error SaleIsClosed();  // Error when trying to buy from a closed sale
error AmountToLow();  // Error when the purchase amount is too small
error AmountToHigh();  // Error when the purchase amount exceeds the allowed limit
error TargetNotReached();  // Error when the target has not been reached during the token sale
error NotAuthorized();  // Error for when the sender isn't authorized (e.g., not the owner)
error InsufficientContractBalance();  // Error when the contract doesn't have enough ETH to withdraw

contract FactoryContract {
    uint256 public constant TARGET = 3 ether;  // Target amount to raise for a token sale (3 ETH)
    uint256 private constant TARGET_LIMIT = 500_000 ether;  // Limit for the total amount to be sold (500,000 ETH)

    uint256 public immutable listingFee;  // Listing fee for creating a token sale
    address public owner;  // Address of the contract owner

    address[] public tokens;  // Array to store the created token addresses
    uint256 public totalTokens;  // Counter for the total number of created tokens
    mapping(address => TokenSale) public tokenToSale;  // Mapping from token address to the TokenSale struct

    bool private locked;  // Lock variable for the non-reentrancy modifier

    struct TokenSale {
        address token;  // Token address for sale
        string name;  // Name of the token
        string description;  // Description of the token
        address creator;  // Address of the token creator
        uint256 sold;  // Amount of tokens sold
        uint256 raised;  // Amount of ETH raised in the sale
        bool isOpen;  // Whether the sale is still open
    }

    event Created(address indexed token);  // Event for token creation
    event Buy(address indexed token, uint256 amount);  // Event for a successful token purchase
    event SaleClosed(address indexed token);  // Event for when a sale is closed
    event TokenListed(address indexed token, string name, string description, address indexed owner);  // Event for listing a token for sale

    // Modifier to restrict access to the contract owner only
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotAuthorized();
        }
        _;
    }

    // Non-reentrancy modifier to prevent reentrancy attacks
    modifier nonReentrant {
        require(!locked, "Reentrancy attempt");
        locked = true;
        _;
        locked = false;
    }

    // Constructor to set the initial listing fee and owner
    constructor(uint256 _listingFee) {
        listingFee = _listingFee;
        owner = msg.sender;
    }

    // Function to create a new token sale
    function createToken(
        string memory _name,
        string memory _symbol,
        string memory _description
    ) public payable {

        // Ensure that the listing fee is sent with the transaction
        if (msg.value != listingFee) {
            revert ListingFeerequired();
        }
   
        // Instantiate a new token with a total supply of 1 million tokens
        Token token = new Token(_name, _symbol, 1_000_000 ether);

        // Store the created token's address in the tokens array
        tokens.push(address(token));

        // Increment the total token counter
        totalTokens++;

        // Create a new TokenSale struct and store it in the mapping
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

        // Emit events for token creation and listing
        emit Created(address(token));
        emit TokenListed(address(token), _name, _description, owner);
    }

    // Function for users to buy tokens from an active sale
    function buyToken(address _token, uint256 _amount) external payable nonReentrant {
        // Get the token sale associated with the provided token address
        TokenSale storage sale = tokenToSale[_token];

        // Ensure that the sale is still open
        if (!sale.isOpen) {
            revert SaleIsClosed();
        }

        // Ensure the purchase amount is at least 1 token (1 ether)
        if (_amount < 1 ether) {
            revert AmountToLow();
        }

        // Ensure the purchase amount doesn't exceed 10,000 tokens (10,000 ether)
        if (_amount > 10000 ether) {
            revert AmountToHigh();
        }

        // Get the cost price of the token based on the number of tokens already sold
        uint256 cost = getCostPrice(sale.sold);

        // Calculate the total price for the purchase
        uint256 price = cost * (_amount / 1 ether);

        // Ensure that the user has sent enough ETH to cover the purchase
        if (msg.value < price) {
            revert InsufficientFunds();
        }

        // Update the sale data with the purchased amount and raised funds
        sale.sold += _amount;
        sale.raised += price;

        // Close the sale if the target limit or target amount has been reached
        if (sale.sold >= TARGET_LIMIT || sale.raised >= TARGET) {
            sale.isOpen = false;
        }

        // Transfer the purchased tokens to the buyer
        Token(_token).transfer(msg.sender, _amount);

        // Emit events for the purchase and sale closure
        emit Buy(_token, _amount);
        emit SaleClosed(_token);
    }

    // Function for the contract to deposit tokens after the sale
    function DepositToken(address _token, string memory _name, string memory _symbol) public nonReentrant {
        require(tokenToSale[_token].creator != address(0), "TokenNotListed");
        
        Token token = new Token(_name, _symbol, 1_000_000 ether);
    
        TokenSale memory sale = tokenToSale[_token];

        // Ensure the target has been reached for the sale
        if (!sale.isOpen) {
            revert TargetNotReached();
        }

        // Transfer the remaining tokens to the creator
        token.transfer(sale.creator, token.balanceOf(address(this)));

        // Transfer the raised ETH to the creator
        (bool success, ) = payable(sale.creator).call{value: sale.raised}("");
        require(success, "ETH transfer failed");
    }

    // Function to allow the owner to withdraw ETH from the contract
    function WithdrawToken(uint256 _amount) public onlyOwner nonReentrant {
        // Ensure the contract has enough balance to make the withdrawal
        if (address(this).balance < _amount) {
            revert InsufficientContractBalance();
        }

        // Transfer the requested amount of ETH to the owner
        (bool success, ) = payable(owner).call{value: _amount}("");
        require(success, "Failed to transfer ETH to creator");
    }

    // Function to get the details of a token sale by index
    function getTokenSale(
        uint256 _index
    ) public view returns (TokenSale memory) {
        return tokenToSale[tokens[_index]];
    }

    // Function to calculate the cost price of a token based on the number of tokens sold
    function getCostPrice(uint256 _sold) public pure returns (uint256) {
        uint256 floor = 0.0001 ether;  // Base price of a token
        uint256 step = 0.0001 ether;   // Increment step per 10,000 tokens sold
        uint256 increment = 10000 ether; // Amount per increment in the pricing curve

        // Calculate the cost price
        uint256 cost = (step * (_sold / increment)) + floor;
        return cost;
    }
}
