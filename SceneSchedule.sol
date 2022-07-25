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
    uint constant InvalidId = 0;
    uint public id = InvalidId;
    uint public startTimestamp = 0; // inclusive
    uint public endTimestamp = 0; // exclusive
    address public booker = address(0);
    string public data;
    bool public removed = false;

    constructor (uint _id, uint _startTimestamp, uint _endTimestamp, address _booker, string memory _data) {
        id = _id;
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
        booker = _booker;
        data = _data;
        removed = false;
    }

    function remove() public {
        removed = true;
    }

    function setBooker(address _booker) public {
        booker = _booker;
    }

    function setData(string memory _data) public {
        data = _data;
    }

    function isValid() public view returns (bool) {
        return id == InvalidId;
        //return (startTimestamp != 0 && endTimestamp != 0 && startTimestamp % 3600 == 0 && endTimestamp % 3600 == 0 && startTimestamp < endTimestamp);
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
    uint private getMySchedulesLimitSeconds;

    uint constant PermissionAdmin = 0xffffffffffffffffffffffffffffffff;
    uint constant PermissionReadOthersSchedule = 0x1;
    uint constant PermissionRemoveOthersSchedule = 0x2;
    mapping(address => uint) permissionMap;

    constructor() payable {
        fee = new FeeCache();

        // add dummy info at the index=0, to use index 0 as NotReserved
        ScheduleInfo dummyInfo = new ScheduleInfo(0, 0, 0, address(0), "");
        schedules.push(dummyInfo);
        createScheduleLimitSeconds = DayInSeconds * 30; // 30 days
        getMySchedulesLimitSeconds = DayInSeconds * 7; // 7 days
        
        permissionMap[owner()] = PermissionAdmin; // grant all the permission to owner
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

    function getEarliestStartingHourTimestampWithPresentTimestamp() public view returns (uint earliestStartTime, uint timestampNow) {
        timestampNow = block.timestamp;
        uint remainder = timestampNow % HourInSeconds;
        earliestStartTime = timestampNow - remainder + HourInSeconds;
    }

    function getEarliestStartingHourTimestamp() public view returns (uint earliestStartTimestamp) {
        (earliestStartTimestamp, ) = getEarliestStartingHourTimestampWithPresentTimestamp();
    }

    function _getSchedules(uint searchStartTimestamp, uint searchEndTimestamp, bool onlyMine) internal returns (ScheduleInfo[] memory mySchedules) {        
        require(searchStartTimestamp % HourInSeconds == 0, "searchStartTimpstamp should point at the starting of an hour.");
        if (searchEndTimestamp == 0)
            searchEndTimestamp = searchStartTimestamp + DayInSeconds*7;
        require(searchEndTimestamp % HourInSeconds == 0, "searchEndTimestamp should point at the starting of an hour.");
        require(searchStartTimestamp < searchEndTimestamp, "searchStarTimestamp should be earlier than searchEndTimestamp.");
        require(searchEndTimestamp - searchStartTimestamp <= getMySchedulesLimitSeconds, "Search range is too broad. searchEndTimestamp - searchStartTimestamp should not be greater than 7 days.");

        uint cacheSize = (searchEndTimestamp - searchStartTimestamp) / HourInSeconds + 1;
        uint [] memory myScheduleStartings = new uint[](cacheSize);
        uint count = 0;
        // calculate size of return array and cache the starting time of my schedules
        for (uint t = searchStartTimestamp; t < searchEndTimestamp; t += HourInSeconds) {
            uint scheduleIndex = scheduleMap[t];            
            if (scheduleIndex != NotReserved) {
                ScheduleInfo info = schedules[scheduleIndex];
                if (onlyMine == false || info.booker() == msg.sender) {
                    myScheduleStartings[count] = t;
                    count++;
                }
            }
        }
   
        mySchedules = new ScheduleInfo[](count);

        // fill the array for return
        for (uint i = 0; i < count; i++) {
            uint t = myScheduleStartings[i];
            uint scheduleIndex = scheduleMap[t];
            ScheduleInfo info = schedules[scheduleIndex];

            // return only if user has a permission to read other's schedule info
            mySchedules[i] = new ScheduleInfo(info.id(), info.startTimestamp(), info.endTimestamp(), address(0), "");
            if (hasPermission(PermissionReadOthersSchedule)) {
                mySchedules[i].setBooker(info.booker());
                mySchedules[i].setData(info.data());
            }
        }

        return mySchedules;
    }

    function getSchedules(uint searchStartTimestamp, uint searchEndTimestamp) public returns (ScheduleInfo[] memory) {
        return _getSchedules(searchStartTimestamp, searchEndTimestamp, false);
    }

    function getMySchedules(uint searchStartTimestamp, uint searchEndTimestamp) public returns (ScheduleInfo[] memory mySchedules) {
        return _getSchedules(searchStartTimestamp, searchEndTimestamp, true);
    }

    function getPresentScheduleStartingTimestamp() public view returns (uint) {
        uint timestampNow = block.timestamp;        
        return timestampNow - (timestampNow % HourInSeconds);
    }

    function getScheduleNow() public view returns (bool scheduleExist, ScheduleInfo scheduleNow) {
        uint presentScheduleStartTimestamp = getPresentScheduleStartingTimestamp();
        uint scheduleIndex = scheduleMap[presentScheduleStartTimestamp];
        if (NotReserved != scheduleMap[presentScheduleStartTimestamp])            
            return (true, schedules[scheduleIndex]);
        scheduleExist = false;
    }

    function getScheduleIndex(uint _startTimestamp) public view returns (uint) {
        require(_startTimestamp % HourInSeconds == 0, "_startTimestamp should point at the starting of each hour");
        return scheduleMap[_startTimestamp];
    }

    function createSchedule(uint _startTimestamp, uint _endTimestamp, string memory _data) public payable returns (ScheduleInfo info) {
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
        info = new ScheduleInfo(schedules.length, _startTimestamp, _endTimestamp, msg.sender, _data);
        schedules.push(info);
        require(schedules[schedules.length-1].id() == schedules.length-1, "new schedule id should be the same as the index in schedules array.");

        for (uint t = _startTimestamp; t < _endTimestamp ; t += HourInSeconds) {
            scheduleMap[t] = info.id();
        }
        

        (bool ret, ) = payable(address(this)).call{value: msg.value}("");
        require(ret, "Failed to send ETH to contract");

        return info;
    }

    function getPermission() internal view returns (uint) {
        return permissionMap[msg.sender];
    }

    function hasPermission(uint permission) internal view returns (bool) {
        return getPermission() & permission == permission;
    }

    function modifySchedule(uint scheduleIndex, uint newStartTimestamp, uint newEndTimestamp, string memory newData) 
        public payable returns (ScheduleInfo newScheduleInfo)
    {
        removeSchedule(scheduleIndex);
        return createSchedule(newStartTimestamp, newEndTimestamp, newData);
    }

    function removeSchedule(uint scheduleIndex) public {
        ScheduleInfo info = schedules[scheduleIndex];
        require(info.isValid(), "You can remove only valid schedules.");
        require(info.removed(), "You can't remove the schedule already removed.");
        require(msg.sender == info.booker() || hasPermission(PermissionRemoveOthersSchedule), "No permission to remove given schedule.");

        for (uint t = info.startTimestamp(); t < info.endTimestamp(); t += HourInSeconds) {
            require(scheduleMap[t] == scheduleIndex, "The time is not occupied by this schedule.");
            scheduleMap[t] = NotReserved;
        }
        info.remove();
    }
}