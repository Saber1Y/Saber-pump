// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

error TotalSupplyisTooLow(uint256 totalSupply);

contract Token is ERC20 {
    address payable public immutable OWNER;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply
    ) ERC20(_name, _symbol) {
        // @param: _name is the name of the token
        // @param: _symbol is the symbol of the token
        // @param: _totalSupply is the total supply of the token
        
        if (_totalSupply < 1e18) {
            revert TotalSupplyisTooLow(_totalSupply);
        }
        
        OWNER = payable(msg.sender);
        _mint(msg.sender, _totalSupply);
    }
}
