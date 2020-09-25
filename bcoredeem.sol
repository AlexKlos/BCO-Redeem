pragma solidity >=0.4.22 <0.7.0;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

interface BCOExtendedToken {
    function burn(uint burnAmount) external;
    function transfer(address _to, uint _value) external returns (bool success);
    function balanceOf(address who) external constant returns (uint);
}

interface TetherToken {
    function transfer(address _to, uint _value) external;
    function balanceOf(address who) external constant returns (uint);
}


contract BCORedeem {
    using SafeMath for uint;

    BCOExtendedToken bcoContract = BCOExtendedToken(0x08ECa7A3b77664381B1C96f8657dE24bf1e307E5);
    TetherToken tetherTokenContract = TetherToken(0x3096e8581d08e01FBC813C2603EB6e10268A76D7);
    mapping (address => address) private bcoBurnerAddressMap;
    address private owner;
    uint private timeLimit;

    constructor(uint _timeLimit) public {
        owner = msg.sender;
        timeLimit = _timeLimit;
    }

    function redeem() external returns (address bcoBurnerAddress) {

        require(bcoContract.balanceOf(msg.sender) != 0);
        require(tetherTokenContract.balanceOf(address(this)) != 0);

        if (bcoBurnerAddressMap[msg.sender] == 0) {

        }
    }

    function getBCOBurnerAddress() public view returns (address bcoBurnerAddress) {
        return bcoBurnerAddressMap[msg.sender];
    }

    function getBCOBurnerAddress(address _address) public view onlyOwner returns (address bcoBurnerAddress) {
        return bcoBurnerAddressMap[_address];
    }

    modifier onlyOwner() {
        if(msg.sender != owner) revert();
        _;
    }

    function setOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    function setTimeLimit(uint _newTimeLimit) public onlyOwner {
        timeLimit = _newTimeLimit;
    }
}


contract BCOBurner {
    using SafeMath for uint;

    BCOExtendedToken bcoContract = BCOExtendedToken(0x08ECa7A3b77664381B1C96f8657dE24bf1e307E5);
    TetherToken tetherTokenContract = TetherToken(0x3096e8581d08e01FBC813C2603EB6e10268A76D7);
    address private owner;
    address private bcoRedeemOwner;
    address private bcoRedeemAddress;
    uint private timeStamp;
    uint private timeLimit;

    constructor(address _owner, address _bcoRedeemOwner, address _bcoRedeemAddress, uint _timeLimit) public {
        owner = _owner;
        bcoRedeemOwner = _bcoRedeemOwner;
        bcoRedeemAddress = _bcoRedeemAddress;
        timeStamp = now;
        timeLimit = _timeLimit;
    }

    function getTimeStamp() public view returns (uint _timeStamp) {
        return timeStamp;
    }

    function getTimeLimit() public view returns (uint _timeLimit) {
        return timeLimit;
    }

    function burn() public onlyOwner {
        require(tetherTokenContract.balanceOf(address(this)) > 0);
        uint tetherBalance = tetherTokenContract.balanceOf(address(this));
        uint bcoBalance = bcoContract.balanceOf(address(this));

        if (bcoBalance == 0) {
            tetherTokenContract.transfer(bcoRedeemAddress, tetherBalance);
        }
        if (bcoBalance < tetherBalance) {
            tetherTokenContract.transfer(bcoRedeemAddress, SafeMath.sub(tetherBalance, bcoBalance));
            bcoContract.burn(bcoBalance);
            tetherTokenContract.transfer(owner, bcoBalance);
        }
        if (bcoBalance >= tetherBalance) {
            bcoContract.burn(tetherBalance);
            tetherTokenContract.transfer(owner, tetherBalance);
        }
    }

    modifier onlyOwner() {
        if(msg.sender != owner) revert();
        _;
    }

    function reset() public onlyBCORedeemOwner {
        require(now >= SafeMath.add(timeStamp, timeLimit) &&
            tetherTokenContract.balanceOf(address(this)) > bcoContract.balanceOf(address(this)));

        uint overcapacity = SafeMath.sub(tetherTokenContract.balanceOf(address(this)), bcoContract.balanceOf(address(this)));
        tetherTokenContract.transfer(bcoRedeemAddress, overcapacity);
    }

    modifier onlyBCORedeemOwner() {
        if(msg.sender != bcoRedeemOwner) revert();
        _;
    }
}