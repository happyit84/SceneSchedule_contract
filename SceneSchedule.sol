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
    address public booker;
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
    mapping(uint => uint) scheduleMap; // each starting hour timpstamp => index in schedules
    uint constant NotReserved = 0; // value for representing not reserved in scheduleMap
    uint constant MinuteInSeconds = 60;
    uint constant HourInSeconds = MinuteInSeconds * 60;
    uint constant DayInSeconds = HourInSeconds * 24;
    uint private createScheduleLimitSeconds; // from present point only can create schedule within this value of seconds in the future

    constructor() payable {
        fee = new FeeCache();

        // add dummy info at the index=0, to use index 0 as NotReserved
        ScheduleInfo dummyInfo = new ScheduleInfo(0, 0, address(0), "");
        schedules.push(dummyInfo);
        createScheduleLimitSeconds = 30 * 24 * 60 * 60; // 30 days
    }

    receive() external payable {} // need payable keyword to get ETH

    function getTimestampNow() public view returns (uint) {
        return block.timestamp;
    }

    function balance() public view onlyOwner returns (uint) {        
        return address(this).balance;
    }
    
    function setFee(uint newFeeWeiPerSecond) public onlyOwner {
        fee.setFee(newFeeWeiPerSecond);
    }

    function getCreateScheduleLimitSeconds() public view returns (uint) {
        return createScheduleLimitSeconds;
    }
    function setCreateScheduleLimitSeconds(uint newValue) public onlyOwner {
        createScheduleLimitSeconds = newValue;
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

    function getNotReserved() external pure returns (uint) {
        return NotReserved;
    }

    function getEarliestStartingHourTimestamp() public view returns (uint) {
        uint timestampNow = block.timestamp;
        uint remainder = timestampNow % HourInSeconds;
        uint earliestStartTime = timestampNow - remainder + HourInSeconds;
        return earliestStartTime;
    }

    function getMySchedule() public view returns (ScheduleInfo[] memory) {
        uint earliestStarting = getEarliestStartingHourTimestamp();
        uint present = earliestStarting - HourInSeconds;
        uint limitStating = earliestStarting + createScheduleLimitSeconds;

        ScheduleInfo [] memory mySchedules;
        uint count = 0;
        for (uint t = present; t < limitStating; t += HourInSeconds) {
            uint scheduleIndex = scheduleMap[t];            
            if (scheduleIndex != NotReserved) {
                ScheduleInfo info = schedules[scheduleIndex];
                address booker = info.booker();
                if (info.booker() == msg.sender) {
                    count++;
                }
            }
        }
        mySchedules = new ScheduleInfo[count];
    }

    function getScheduleIndex(uint _startTimestamp) public view returns (uint) {
        require(_startTimestamp % HourInSeconds == 0, "_startTimestamp should point at the starting of each hour");
        return scheduleMap[_startTimestamp];
    }

    function createSchedule(uint _startTimestamp, uint _endTimestamp, string memory _data) public payable returns (uint256 scheduleIndex, ScheduleInfo info) {
        // check if timestamp is hour base
        // check start time
        require(_startTimestamp >= block.timestamp, "_startTimestamp should not be past time.");
        require(_startTimestamp % HourInSeconds == 0, "_startTimestamp should point at starting of each hour.");
        uint timestampLimit = getEarliestStartingHourTimestamp() + createScheduleLimitSeconds;
        require(_startTimestamp < timestampLimit, "Too much future time. Check the limit of seconds with getCreateScheduleLimitSeconds()");

        // check end time
        if (_endTimestamp == 0)
            _endTimestamp = _startTimestamp + HourInSeconds;
        else
            require(_endTimestamp % HourInSeconds == 0, "_endTimestamp should point at the starting of each hour.");
        require(_startTimestamp < _endTimestamp, "_startTimestamp should be earlier than _endTimpstamp.");

        // check sent ETH amount
        uint hourCount = (_endTimestamp - _startTimestamp) / HourInSeconds;
        uint feePerHour = getFeePerHour();
        uint totalFee = hourCount * feePerHour;
        uint value = msg.value;

        if (value < totalFee)
            revert("ETH amount is not enough to create schedule for given period.");
        else if (value > totalFee)
            revert("ETH amount is too much to create schedule for given period.");


        // check if time slot is avaiable
        for (uint t = _startTimestamp; t < _endTimestamp ; t += HourInSeconds) {
            require(NotReserved == scheduleMap[t], "There's already reserved time.") ;
        }

        // execute creating schedule
        info = new ScheduleInfo(_startTimestamp, _endTimestamp, msg.sender, _data);
        schedules.push(info);
        scheduleIndex = schedules.length - 1;

        for (uint t = _startTimestamp; t < _endTimestamp ; t += HourInSeconds) {
            scheduleMap[t] = scheduleIndex;
        }

        (bool ret, ) = payable(address(this)).call{value: msg.value}("");
        require(ret, "Failed to send ETH to contract");

        return (scheduleIndex, info);
    }
}