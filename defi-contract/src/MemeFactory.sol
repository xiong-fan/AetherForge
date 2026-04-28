// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MemeToken.sol";

/**
 * @title IUniswapV2Router02
 * @dev Minimal interface for Uniswap V2 Router
 */
interface IUniswapV2Router02 {
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

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

/**
 * @title IUniswapV2Factory
 * @dev Minimal interface for Uniswap V2 Factory
 */
interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

/**
 * @title MemeFactory
 * @dev Factory contract to create Meme tokens using minimal proxy pattern
 *      Integrates with Uniswap V2 for automatic liquidity provision
 */
contract MemeFactory is Ownable {
    using Clones for address;

    // Implementation contract address
    address public immutable implementation;

    // Uniswap V2 Router
    IUniswapV2Router02 public immutable uniswapRouter;

    // Platform fee receiver (project party)
    address public platformFeeReceiver;

    // Platform fee percentage (5%)
    uint256 public constant PLATFORM_FEE_PERCENT = 5;

    // Creator fee percentage (95%)
    uint256 public constant CREATOR_FEE_PERCENT = 95;

    // Liquidity percentage from platform fee (5% of total, which is 100% of platform fee)
    uint256 public constant LIQUIDITY_PERCENT = 100; // 100% of platform fee goes to liquidity

    struct MemeInfo {
        address tokenAddress;
        address creator;
        string symbol;
        uint256 totalSupply;
        uint256 perMint;
        uint256 price;
        uint256 totalMinted;
        bool exists;
    }

    // Mapping from token address to MemeInfo
    mapping(address => MemeInfo) public memes;

    // Array of all meme token addresses
    address[] public allMemes;

    // Mapping to track if liquidity has been added for a token
    mapping(address => bool) public liquidityAdded;

    // Events
    event MemeDeployed(
        address indexed tokenAddress,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );

    event MemeMinted(
        address indexed tokenAddress,
        address indexed buyer,
        uint256 amount,
        uint256 cost,
        uint256 platformFee,
        uint256 creatorFee
    );

    event LiquidityAdded(
        address indexed tokenAddress,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );

    event MemeBought(
        address indexed tokenAddress,
        address indexed buyer,
        uint256 amountOut,
        uint256 ethIn
    );

    constructor(address _uniswapRouter) Ownable(msg.sender) {
        require(_uniswapRouter != address(0), "Invalid router address");

        // Deploy implementation contract
        implementation = address(new MemeToken());

        // Set Uniswap router
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);

        // Set platform fee receiver to deployer
        platformFeeReceiver = msg.sender;
    }

    /**
     * @dev Deploy a new Meme token using minimal proxy
     * @param symbol Token symbol
     * @param totalSupply Total supply of tokens
     * @param perMint Amount minted per transaction
     * @param price Price per mint in wei
     */
    function deployMeme(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(totalSupply > 0, "Total supply must be positive");
        require(perMint > 0 && perMint <= totalSupply, "Invalid perMint amount");
        require(price > 0, "Price must be positive");

        // Clone the implementation
        address clone = implementation.clone();

        // Initialize the clone
        MemeToken(clone).initialize(
            symbol,
            msg.sender,
            totalSupply,
            perMint,
            price
        );

        // Store meme info
        memes[clone] = MemeInfo({
            tokenAddress: clone,
            creator: msg.sender,
            symbol: symbol,
            totalSupply: totalSupply,
            perMint: perMint,
            price: price,
            totalMinted: 0,
            exists: true
        });

        allMemes.push(clone);

        emit MemeDeployed(clone, msg.sender, symbol, totalSupply, perMint, price);

        return clone;
    }

    /**
     * @dev Mint Meme tokens by paying ETH
     * @param tokenAddr Address of the Meme token
     */
    function mintMeme(address tokenAddr) external payable {
        require(memes[tokenAddr].exists, "Meme does not exist");

        MemeInfo storage meme = memes[tokenAddr];
        MemeToken token = MemeToken(tokenAddr);

        require(token.remainingSupply() >= meme.perMint, "Insufficient supply");

        // Calculate cost for this mint
        uint256 cost = meme.price * meme.perMint;
        require(msg.value >= cost, "Insufficient payment");

        // Calculate fees
        uint256 platformFee = (cost * PLATFORM_FEE_PERCENT) / 100;
        uint256 creatorFee = cost - platformFee;

        // Mint tokens to buyer
        token.mint(msg.sender);
        meme.totalMinted += meme.perMint;

        // Transfer creator fee
        (bool successCreator, ) = meme.creator.call{value: creatorFee}("");
        require(successCreator, "Creator fee transfer failed");

        // Handle platform fee and liquidity
        // All platform fee (5%) goes to liquidity as ETH + tokens
        if (platformFee > 0) {
            // Calculate token amount for liquidity based on mint price
            uint256 tokenAmountForLiquidity = platformFee / meme.price;

            // Check if we need to mint tokens for liquidity
            if (token.remainingSupply() >= tokenAmountForLiquidity) {
                // Mint tokens for liquidity
                token.mint(address(this));

                // Approve router to spend tokens
                IERC20(tokenAddr).approve(address(uniswapRouter), tokenAmountForLiquidity);

                // Add liquidity
                try uniswapRouter.addLiquidityETH{value: platformFee}(
                    tokenAddr,
                    tokenAmountForLiquidity,
                    0, // Accept any amount of tokens
                    0, // Accept any amount of ETH
                    address(this), // LP tokens go to factory
                    block.timestamp + 300
                ) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
                    liquidityAdded[tokenAddr] = true;
                    emit LiquidityAdded(tokenAddr, amountToken, amountETH, liquidity);
                } catch {
                    // If adding liquidity fails, send ETH to platform fee receiver
                    (bool successPlatform, ) = platformFeeReceiver.call{value: platformFee}("");
                    require(successPlatform, "Platform fee transfer failed");
                }
            } else {
                // Not enough tokens for liquidity, send to platform fee receiver
                (bool successPlatform, ) = platformFeeReceiver.call{value: platformFee}("");
                require(successPlatform, "Platform fee transfer failed");
            }
        }

        // Refund excess payment
        if (msg.value > cost) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - cost}("");
            require(refundSuccess, "Refund failed");
        }

        emit MemeMinted(tokenAddr, msg.sender, meme.perMint, cost, platformFee, creatorFee);
    }

    /**
     * @dev Buy Meme tokens from Uniswap if price is better than mint price
     * @param tokenAddr Address of the Meme token
     */
    function buyMeme(address tokenAddr) external payable {
        require(memes[tokenAddr].exists, "Meme does not exist");
        require(liquidityAdded[tokenAddr], "No liquidity available");
        require(msg.value > 0, "Must send ETH");

        MemeInfo storage meme = memes[tokenAddr];

        // Create path for swap
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = tokenAddr;

        // Get expected output from Uniswap
        uint256[] memory amounts = uniswapRouter.getAmountsOut(msg.value, path);
        uint256 expectedTokens = amounts[1];

        // Calculate how many tokens we'd get at mint price
        uint256 tokensAtMintPrice = (msg.value * meme.perMint) / meme.price;

        // Only proceed if Uniswap price is better (more tokens for same ETH)
        require(expectedTokens > tokensAtMintPrice, "Mint price is better");

        // Perform swap
        uint256[] memory swapAmounts = uniswapRouter.swapExactETHForTokens{value: msg.value}(
            0, // Accept any amount of tokens
            path,
            msg.sender,
            block.timestamp + 300
        );

        emit MemeBought(tokenAddr, msg.sender, swapAmounts[1], msg.value);
    }

    /**
     * @dev Get Uniswap price vs mint price comparison
     * @param tokenAddr Address of the Meme token
     * @param ethAmount Amount of ETH to check
     * @return uniswapTokens Tokens available from Uniswap
     * @return mintTokens Tokens available from minting
     * @return isBetterPrice True if Uniswap price is better
     */
    function getPriceComparison(address tokenAddr, uint256 ethAmount)
        external
        view
        returns (uint256 uniswapTokens, uint256 mintTokens, bool isBetterPrice)
    {
        require(memes[tokenAddr].exists, "Meme does not exist");

        MemeInfo storage meme = memes[tokenAddr];
        mintTokens = (ethAmount * meme.perMint) / meme.price;

        if (!liquidityAdded[tokenAddr]) {
            return (0, mintTokens, false);
        }

        // Try to get Uniswap price
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = tokenAddr;

        try uniswapRouter.getAmountsOut(ethAmount, path) returns (uint256[] memory amounts) {
            uniswapTokens = amounts[1];
            isBetterPrice = uniswapTokens > mintTokens;
        } catch {
            uniswapTokens = 0;
            isBetterPrice = false;
        }
    }

    /**
     * @dev Get all meme tokens
     */
    function getAllMemes() external view returns (address[] memory) {
        return allMemes;
    }

    /**
     * @dev Get meme count
     */
    function getMemeCount() external view returns (uint256) {
        return allMemes.length;
    }

    /**
     * @dev Update platform fee receiver (only owner)
     */
    function setPlatformFeeReceiver(address _receiver) external onlyOwner {
        require(_receiver != address(0), "Invalid receiver");
        platformFeeReceiver = _receiver;
    }

    /**
     * @dev Check if liquidity exists for a token on Uniswap
     */
    function hasUniswapLiquidity(address tokenAddr) external view returns (bool) {
        address factory = uniswapRouter.factory();
        address weth = uniswapRouter.WETH();
        address pair = IUniswapV2Factory(factory).getPair(tokenAddr, weth);
        return pair != address(0);
    }

    // Allow contract to receive ETH
    receive() external payable {}
}
