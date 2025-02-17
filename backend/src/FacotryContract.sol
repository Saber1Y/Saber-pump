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

    address[] public tokens; // array of created tokens
    uint256 public totalTokens;
    mapping(address => TokenSale) public tokenToSale;
    mapping(address => bool) public whitelisted; // whitelist for approved buyers
    mapping(address => uint256) public referralEarnings; // stores referral rewards

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
    event Whitelisted(address indexed user);
    event ReferralReward(address indexed referrer, uint256 amount);
    event Withdrawn(address indexed creator, uint256 amount);
    event SaleClosed(address indexed token);

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotAuthorized();
        }
        _;
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
        if (msg.value >= 0) {
            revert ListingFeerequired();
        }
        // allow creation of tokens through token instantiation
        Token token = new Token(msg.sender, _name, _symbol, 1_000_000 ether);

        tokens.push(address(token)); // pushing each created token into the array

        totalTokens++; // increment total tokens

        // list the token for sale
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
    }

    function buyToken(address _token, uint256 _amount, address _referrer) external payable {
        // ensure user is whitelisted before purchase
        if (!whitelisted[msg.sender]) {
            revert NotAuthorized();
        }

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

        uint256 price = cost * (_amount / 10 ** 10);

        if (msg.value < price) {
            revert InsufficientFunds();
        }

        uint256 ownerFee = (price * 3) / 100; // 3% fee goes to owner
        uint256 referrerReward = (price * 2) / 100; // 2% referral reward

        sale.sold += _amount;
        sale.raised += (price - ownerFee - referrerReward); // deduct fees from raised amount

        if (sale.sold >= TARGET_LIMIT || sale.raised >= TARGET) {
            sale.isOpen = false;
        }

        Token(_token).transfer(msg.sender, _amount);

        // send owner fee
        payable(owner).transfer(ownerFee);

        // send referral reward if referrer is valid
        if (_referrer != address(0) && _referrer != msg.sender) {
            referralEarnings[_referrer] += referrerReward;
            emit ReferralReward(_referrer, referrerReward);
        }

        emit Buy(_token, _amount);
    }

    function whitelistUser(address _user) external onlyOwner {
        whitelisted[_user] = true;
        emit Whitelisted(_user);
    }

    function withdrawReferralEarnings() external {
        uint256 earnings = referralEarnings[msg.sender];
        require(earnings > 0, "no earnings to withdraw");

        referralEarnings[msg.sender] = 0;
        payable(msg.sender).transfer(earnings);
    }

    function withdrawCreatorFunds(address _token) external {
        TokenSale storage sale = tokenToSale[_token];

        if (sale.creator != msg.sender) {
            revert NotAuthorized();
        }

        uint256 amount = sale.raised;
        sale.raised = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function closeSale(address _token) external {
        TokenSale storage sale = tokenToSale[_token];

        if (sale.creator != msg.sender) {
            revert NotAuthorized();
        }

        sale.isOpen = false;
        emit SaleClosed(_token);
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
