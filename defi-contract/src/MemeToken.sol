// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MemeToken
 * @dev ERC20 token template for Meme tokens created via minimal proxy
 */
contract MemeToken is ERC20 {
    address public factory;
    address public creator;
    uint256 public totalSupplyAmount;
    uint256 public perMintAmount;
    uint256 public mintPrice;
    uint256 public minted;

    bool private initialized;

    constructor() ERC20("", "") {
        // Empty constructor for implementation contract
    }

    /**
     * @dev Initialize the token (called by factory after clone)
     */
    function initialize(
        string memory _symbol,
        address _creator,
        uint256 _totalSupply,
        uint256 _perMint,
        uint256 _price
    ) external {
        require(!initialized, "Already initialized");
        require(_totalSupply > 0, "Invalid total supply");
        require(_perMint > 0 && _perMint <= _totalSupply, "Invalid per mint amount");
        require(_price > 0, "Invalid price");

        initialized = true;
        factory = msg.sender;
        creator = _creator;
        totalSupplyAmount = _totalSupply;
        perMintAmount = _perMint;
        mintPrice = _price;
        minted = 0;

        // Override storage slots for ERC20 name and symbol
        // This is a workaround since we can't call constructor
        _name = string(abi.encodePacked("Meme ", _symbol));
        _symbol = _symbol;
    }

    /**
     * @dev Mint tokens to a user (only callable by factory)
     */
    function mint(address to) external returns (uint256) {
        require(msg.sender == factory, "Only factory can mint");
        require(minted + perMintAmount <= totalSupplyAmount, "Exceeds total supply");

        _mint(to, perMintAmount);
        minted += perMintAmount;

        return perMintAmount;
    }

    /**
     * @dev Get remaining mintable amount
     */
    function remainingSupply() external view returns (uint256) {
        return totalSupplyAmount - minted;
    }

    // Storage slots for name and symbol (to support initialization)
    string private _name;
    string private _symbol;

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
}
