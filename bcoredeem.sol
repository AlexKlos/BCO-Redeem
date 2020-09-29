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


/**
 * Контракт для сбора USDT и последующего выкупа BCOExtendedToken у токенхолдеров
 * путём создания контрактов BCOBurner и их контроля с помощью реестра bcoBurnerAddressMap
 */
contract BCORedeem {
    using SafeMath for uint;
    
    BCOExtendedToken bcoContract = BCOExtendedToken(0x08ECa7A3b77664381B1C96f8657dE24bf1e307E5);
    TetherToken tetherTokenContract = TetherToken(0x3096e8581d08e01FBC813C2603EB6e10268A76D7);
    mapping (address => address) private bcoBurnerAddressMap;   // Реест контрактов BCOBurner
    address private owner;
    uint private timeLimit;   // Время гарантированной работы контракта BCOBurner
    
    constructor(uint _timeLimit) public {
        owner = msg.sender;
        timeLimit = _timeLimit;
    }

    /**
     * Функция работает при наличии USDT на балансе контракта и BCO на балансе вызывающего адреса. 
     * При отсутствии адреса, вызывающего функцию, в реестре bcoBurnerAddressMap, создаёт контракт BCOBurner,
     * переводит на него USDT для выкупа BCO и возвращает адрес созданного контракта BCOBurner.
     * Если адрес, вызвавший функцию, присутствует в реестре, то переводит на него недостающую сумму USDT 
     * для выкупа BCO и возвращает адрес контракта BCOBurner. 
     */
    function redeem() external returns (address bcoBurnerAddress) {
        
        require(bcoContract.balanceOf(msg.sender) != 0);
        require(tetherTokenContract.balanceOf(address(this)) != 0);
        
        if (bcoBurnerAddressMap[msg.sender] != 0) {
            address _bcoBurnerAddress = new BCOBurner(msg.sender, owner, address(this), timeLimit);
            bcoBurnerAddressMap[msg.sender] = _bcoBurnerAddress;
            tetherTokenContract.transfer(_bcoBurnerAddress, bcoContract.balanceOf(msg.sender));
            return _bcoBurnerAddress;
        } else {
            _bcoBurnerAddress = bcoBurnerAddressMap[msg.sender];
            if (bcoContract.balanceOf(msg.sender) > tetherTokenContract.balanceOf(_bcoBurnerAddress)) {
                tetherTokenContract.transfer(_bcoBurnerAddress, 
                SafeMath.sub(bcoContract.balanceOf(msg.sender), tetherTokenContract.balanceOf(_bcoBurnerAddress)));
            }
            return _bcoBurnerAddress;
        }
    }
    
    /**
     * Возвращает адрес контракта BCOBurner из реестра bcoBurnerAddressMap для вызывающего адреса
     */
    function getBCOBurnerAddress() public view returns (address bcoBurnerAddress) {
        return bcoBurnerAddressMap[msg.sender];
    }
    
    /**
     * Возвращает адрес контракта BCOBurner из реестра bcoBurnerAddressMap для _address
     */
    function getBCOBurnerAddress(address _address) public view onlyOwner returns (address bcoBurnerAddress) {
        return bcoBurnerAddressMap[_address];
    }
    
    modifier onlyOwner() {
        if(msg.sender != owner) revert();
        _;
    }
    
    /**
     * Функция смены владельца контракта
     * @param _newOwner новый владелец
     */
    function setOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }
    
    /**
     * Функция установки времени гарантированной работы контракта BCOBurner
     * @param _newTimeLimit время гарантированной работы контракта
     */
    function setTimeLimit(uint _newTimeLimit) public onlyOwner {
        timeLimit = _newTimeLimit;
    }
}


/**
 * Контракт для сжигания BCO и возврата USDT
 */
contract BCOBurner {
    using SafeMath for uint;
    
    BCOExtendedToken bcoContract = BCOExtendedToken(0x08ECa7A3b77664381B1C96f8657dE24bf1e307E5);
    TetherToken tetherTokenContract = TetherToken(0x3096e8581d08e01FBC813C2603EB6e10268A76D7);
    address private owner;
    address private bcoRedeemOwner;
    address private bcoRedeemAddress;
    uint private timeStamp;   // Время деплоя контракта
    uint private timeLimit;   // Время гарантированной работы контракта
    
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
    
    /**
     * Функция работает при наличии USDT на балансе контракта.
     * Сжигает BCO со своего баланса, равное количеству USDT на своём балансе, и отправляет 
     * USDT, равное количеству сожжёных BCO, на адрес owner.
     * Если BCO на балансе контракта было меньше, чем USDT, то остаток USDT возвращает на 
     * адрес bcoRedeemAddress.
     * Если BCO на балансе контракта отсутствует, то возвращает весь USDT на адрес bcoRedeemAddress.
     */
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
    
    /**
     * Функция работет после окончания timeLimit и наличии излишка USDT на балансе.
     * Позволяет владельцу контракта BCORedeem вывести излишек USDT с баланса контракта обратно на адрес контракта BCORedeem.
     */
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