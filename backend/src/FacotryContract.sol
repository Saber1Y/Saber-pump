// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/*///////////////////////////////////////////////////////////////*/
                            IMPORTS
    //////////////////////////////////////////////////////////////*/
import {Token} from "./Token.sol";

/*///////////////////////////////////////////////////////////////*/
                            ERRORS
    //////////////////////////////////////////////////////////////*/
error ListingFeerequired();
error InsufficientFunds();
error SaleIsClosed();
error AmountToLow();
error AmountToHigh();
error TargetNotReached();
error NotAuthorized();
error IndexOutOfBounds();

/*///////////////////////////////////////////////////////////////*/
                        TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/
/**
 * @dev Struct to store details of a token sale.
 */
struct TokenSale {
    address token; // Address of the token being sold.
    string name; // Name of the token.
    string image; // Image associated with the token.
    string description; // Description of the token.
    address creator; // Address of the token creator.
    uint256 sold; // Total amount of tokens sold.
    uint256 raised; // Total funds raised in the sale.
    bool isOpen; // Whether the sale is still open.
}

/*///////////////////////////////////////////////////////////////*/
                        STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
uint256 public constant TARGET = 3 ether; // Fundraising target for each token sale.
uint256 private constant TARGET_LIMIT = 500_000 ether; // Maximum tokens that can be sold.

uint256 public immutable listingFee; // Fee required to create a new token.
address public owner; // Address of the contract owner.

address[] public tokens; // Array of created token addresses.
uint256 public totalTokens; // Total number of tokens created.
mapping(address => TokenSale) public tokenToSale; // Mapping of token address to sale details.
mapping(address => uint256) public referralEarnings; // Mapping of referrer addresses to their earnings.

/*///////////////////////////////////////////////////////////////*/
                            EVENTS
    //////////////////////////////////////////////////////////////*/
event Created(address indexed token);
event Buy(address indexed token, uint256 amount);
event Whitelisted(address indexed user);
event ReferralReward(address indexed referrer, uint256 amount);
event Withdrawn(address indexed creator, uint256 amount);
event SaleClosed(address indexed token);

/*///////////////////////////////////////////////////////////////*/
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/
/**
 * @dev Restricts access to the owner of the contract.
 */
modifier onlyOwner() {
    if (msg.sender != owner) {
        revert NotAuthorized();
    }
    _;
}

/*///////////////////////////////////////////////////////////////*/
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
/**
 * @dev Initializes the contract with the listing fee and sets the owner.
 * @param _listingFee The fee required to create a new token.
 */
constructor(uint256 _listingFee) {
    listingFee = _listingFee;
    owner = msg.sender;
}

/*///////////////////////////////////////////////////////////////*/
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
/**
 * @dev Allows users to create a new token by paying the listing fee.
 * @param _name The name of the token.
 * @param _symbol The symbol of the token.
 * @param _description A description of the token.
 * @param _image An image associated with the token.
 */
function createToken(
    string memory _name,
    string memory _symbol,
    string memory _description,
    string memory _image
) external payable {
    if (msg.value < listingFee) {
        revert ListingFeerequired();
    }

    // Deploy a new token contract.
    Token token = new Token(msg.sender, _name, _symbol, 1_000_000 ether);

    // Store the token address in the tokens array.
    tokens.push(address(token));
    totalTokens++;

    // Initialize the token sale details.
    TokenSale memory sale = TokenSale(
        address(token),
        _name,
        _image,
        _description,
        msg.sender,
        0,
        0,
        true
    );

    // Map the token address to its sale details.
    tokenToSale[address(token)] = sale;

    emit Created(address(token));
}

/**
 * @dev Allows users to buy tokens from an open sale.
 * @param _token The address of the token being purchased.
 * @param _amount The amount of tokens to buy.
 * @param _referrer The address of the referrer (optional).
 */
function buyToken(
    address _token,
    uint256 _amount,
    address _referrer
) external payable {
    TokenSale storage sale = tokenToSale[_token];

    if (!sale.isOpen) {
        revert SaleIsClosed();
    }

    if (_amount < 1 ether) {
        revert AmountToLow();
    }

    if (_amount > 10000 ether) {
        revert AmountToHigh();
    }

    uint256 cost = getCostPrice(sale.sold);
    uint256 price = cost * (_amount / 10 ** 10);

    if (msg.value < price) {
        revert InsufficientFunds();
    }

    uint256 ownerFee = (price * 3) / 100; // 3% fee to the owner.
    uint256 referrerReward = (price * 2) / 100; // 2% referral reward.

    sale.sold += _amount;
    sale.raised += (price - ownerFee - referrerReward);

    if (sale.sold >= TARGET_LIMIT || sale.raised >= TARGET) {
        sale.isOpen = false;
    }

    Token(_token).transfer(msg.sender, _amount);

    // Transfer owner fee.
    payable(owner).transfer(ownerFee);

    // Transfer referral reward if applicable.
    if (_referrer != address(0) && _referrer != msg.sender) {
        referralEarnings[_referrer] += referrerReward;
        emit ReferralReward(_referrer, referrerReward);
    }

    emit Buy(_token, _amount);
}

/**
 * @dev Allows the token creator to close the sale.
 * @param _token The address of the token.
 */
function closeSale(address _token) external {
    TokenSale storage sale = tokenToSale[_token];

    if (sale.creator != msg.sender) {
        revert NotAuthorized();
    }

    sale.isOpen = false;
    emit SaleClosed(_token);
}

/*///////////////////////////////////////////////////////////////*/
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
/**
 * @dev Returns the sale details of a token by its index.
 * @param _index The index of the token in the tokens array.
 * @return TokenSale The sale details of the token.
 */
function getTokenSale(uint256 _index) public view returns (TokenSale memory) {
    return tokenToSale[tokens[_index]];
}

/**
 * @dev Returns the creator of a token by its index.
 * @param _index The index of the token in the tokens array.
 * @return address The address of the token creator.
 */
function getTokenCreator(uint256 _index) public view returns (address) {
    if (_index >= tokens.length) {
        revert IndexOutOfBounds();
    }
    return tokenToSale[tokens[_index]].creator;
}

/*///////////////////////////////////////////////////////////////*/
                        PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
/**
 * @dev Calculates the cost price of tokens based on how many have been sold.
 * @param _sold The total amount of tokens sold so far.
 * @return uint256 The cost price per token (in wei).
 */
function getCostPrice(uint256 _sold) public pure returns (uint256) {
    uint256 floor = 0.0001 ether;
    uint256 step = 0.0001 ether;
    uint256 increment = 10000 ether;

    uint256 cost = (step * (_sold / increment)) + floor;
    return cost;
}