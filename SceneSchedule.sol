// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FeeCache {
    uint256 private feeWeiPerSecond;
    uint256 private feeWeiPerMinute;
    uint256 private feeWeiPerHour;
    uint256 private feeWeiPerDay;

    constructor() {
        setFee(1);
    }

    function setFee(uint256 newFeeWeiPerSecond) public {
        feeWeiPerSecond = newFeeWeiPerSecond;
        feeWeiPerMinute = 60 * feeWeiPerSecond;
        feeWeiPerHour = 60 * feeWeiPerMinute;
        feeWeiPerDay = 24 * feeWeiPerHour;
    }

    function getFeePerSecond() public view returns (uint256 weiPerSecond) {
        return feeWeiPerSecond;
    }

    function getFeePerMinute() public view returns (uint256 weiPerMinute) {
        return feeWeiPerMinute;
    }

    function getFeePerHour() public view returns (uint256 weiPerHour) {
        return feeWeiPerHour;
    }

    function getFeePerDay() public view returns (uint256 weiPerDay) {
        return feeWeiPerDay;
    }
}

contract ScheduleInfo {
    uint public startTimestamp; // inclusive
    uint public endTimestamp; // exclusive
    address booker;
    string public data;

    constructor (uint _startTimestamp, uint _endTimestamp, address _booker, string memory _data) {
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
        booker = _booker;
        data = _data;
    }
}

contract SceneSchedule is Ownable {
    FeeCache private fee;
    ScheduleInfo [] schedules;
    mapping(uint => uint) scheduleMap; // each starting hour => index in schedules
    uint constant NotReserved = 0; // value for representing not reserved in scheduleMap

    constructor() {
        fee = new FeeCache();
    }

    function getTimestampNow() public view returns (uint) {
        return block.timestamp;
    }

    function balance() public view onlyOwner returns (uint) {
        return address(this).balance;
    }
    
    function setFee(uint256 newFeeWeiPerSecond) public onlyOwner {
        fee.setFee(newFeeWeiPerSecond);
    }

    function getFeePerSecond() public view returns (uint256 weiPerSecond) {
        return fee.getFeePerSecond();
    }

    function getFeePerMinute() public view returns (uint256 weiPerMinute) {
        return fee.getFeePerMinute();
    }

    function getFeePerHour() public view returns (uint256 weiPerHour) {
        return fee.getFeePerHour();
    }
    
    function getFeePerDay() public view returns (uint256 weiPerDay) {
        return fee.getFeePerDay();
    }

    function createSchedule(uint _startTimestamp, uint _endTimestamp, string memory _data) external payable returns (uint256 scheduleIndex) {
        // check if timestamp is hour base
        require(_startTimestamp >= block.timestamp, "_startTimestamp should not be past time.");
        require(_startTimestamp % 3600 == 0, "_startTimestamp should point at starting of each hour.");
        require(_endTimestamp % 3600 == 0, "_endTimestamp should point at the starting of each hour.");
        require(_startTimestamp < _endTimestamp, "_startTimestamp should be earlier than _endTimpstamp.");

        uint hourCount = (_endTimestamp - _startTimestamp) / 3600;

        if (msg.value < hourCount * getFeePerHour())
            revert("ETH amount is not enough to create schedule for given period.");
        else if (msg.value > hourCount * getFeePerHour())
            revert("ETH amount is too much to create schedule for given period.");


        for (uint t = _startTimestamp; t < _endTimestamp ; t += 3600) {
            if (NotReserved != scheduleMap[t]) 
                revert("There's already reserved time.");
        }

        ScheduleInfo info = new ScheduleInfo(_startTimestamp, _endTimestamp, msg.sender, _data);
        schedules.push(info);
        scheduleIndex = schedules.length - 1;

        for (uint t = _startTimestamp; t < _endTimestamp ; t += 3600) {
            scheduleMap[t] = scheduleIndex;
        }

        payable(address(this)).transfer(msg.value);

        return scheduleIndex;
    }
}