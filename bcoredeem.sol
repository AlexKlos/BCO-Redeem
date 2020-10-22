pragma solidity >=0.4.25 <0.7.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 */
library SafeMath {
    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint a, uint b) internal pure returns (uint) {
        if (a == 0) {
            return 0;
        }
        uint c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint a, uint b) internal pure returns (uint) {
       // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint a, uint b) internal pure returns (uint) {
        assert(b <= a);
        return a - b;
    }
}

/**
 Interface for accessing BCO smart contract functions. 
 */
interface BCOExtendedToken {
    function burn(uint burnAmount) external;
    function transfer(address _to, uint _value) external returns (bool success);
}

/**
 Interface for accessing USDT smart contract functions. 
 */
interface TetherToken {
    function transfer(address _to, uint _value) external;
    function balanceOf(address who) external returns (uint);
}


/**
 BCOredeem allows to accumulate USDT and exchange BCO for USDT when an external 
 address transfers BCO to a contract address.
 
 The contract logic is contained in a single function - tokenFallback, 
 which is called by the transfer function when a BCO is received.
 */
contract BCORedeem {
    using SafeMath for uint;
    
    // ------
    // STATE
    // ------
    
    // BCO contract reference
    BCOExtendedToken private bcoContract;
    // BCO contract address
    address private bcoContractAddress = 0x08ECa7A3b77664381B1C96f8657dE24bf1e307E5;
    // USDT contract reference
    TetherToken private tetherTokenContract;
    // USDT contract address
    address private tetherTokenContractAddress = 0x3096e8581d08e01FBC813C2603EB6e10268A76D7;
    // Contract owner address
    address private owner;
    // Redeem price (0.01$)
    uint private price;
    
    // ---------
    // FUNCTIONS
    // ---------
    
    constructor(uint _price) public {
        owner = msg.sender;
        price = _price;
        bcoContract = BCOExtendedToken(bcoContractAddress);
        tetherTokenContract = TetherToken(tetherTokenContractAddress);
    }

    /**
     @dev               Called by the transfer function when transferring 
                        BCO to the contract address. Exchange BCO to USDT, 
                        burn BCO and receive USDT to BCO sender address 
                        considering the redeem price.
                        Require the USDT balance > 0 and called contract is BCO contract.
                        If the USDT balance is less than the received BCO, 
                        it returns the oversupply to the sender.
     
     @param _to         The address to receive USDT
     @param _value      The BCO transaction volume
     */
    function tokenFallback(address _to, uint _value) external {
        
        require(msg.sender == bcoContractAddress);
        require(tetherTokenContract.balanceOf(address(this)) != 0);

        // Calculating the volume of USDT to transfer considering 
        // the redeem price and the difference in decimals
        uint _tempVar = SafeMath.mul(_value, price);  
        uint _usdtForTransfer = SafeMath.div(_tempVar, 10000);
        
        if(_usdtForTransfer > tetherTokenContract.balanceOf(address(this))) {
            // If the USDT balance is less than the received BCO
            // Correct the volume of USDT to transfer
            _usdtForTransfer = tetherTokenContract.balanceOf(address(this));
            _tempVar = SafeMath.mul(_usdtForTransfer, 10000);
            // Correct BCO for burn fnd burn
            uint _bcoForBurn = SafeMath.div(_tempVar, price);
            bcoContract.burn(_bcoForBurn);
            // Returns the BCO oversupply to the sender
            uint _bcoForReturn = SafeMath.sub(_value, _bcoForBurn);
            bcoContract.transfer(_to, _bcoForReturn);
            // Receive USDT
            tetherTokenContract.transfer(_to, _usdtForTransfer);
        } else {
            // If the USDT balance is enough than just burn BCO and receive USDT
            bcoContract.burn(_value);
            tetherTokenContract.transfer(_to, _usdtForTransfer);
        }
        
    }
    
    /**
     @dev                Modifer that allows a function to be called by the contract owner
    */
    modifier onlyOwner() {
        if(msg.sender != owner) revert();
        _;
    }
    
    // ----------------
    // SETTER FUNCTIONS
    // ----------------
    
    /**
     @dev               Transfer ownable to new address   
     @param _newOwner   The new owner
    */
    function setOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }
    
    /**
     @dev               Changes the redeem price
     @param _price      The new price
     */
    function setPrice(uint _price) public onlyOwner {
        price = _price;
    }
    
    // ----------------
    // GETTER FUNCTIONS
    // ----------------
    
    /**
     @dev                Get the redeem price
     @return             The redeem price
     */
    function getPrice() public view returns (uint) {
        return price;
    }
    
}