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

contract Schedule {
    uint constant InvalidId = 0;
    uint public id = InvalidId;
    uint public startTimestamp = 0; // inclusive
    uint public endTimestamp = 0; // exclusive
    address public booker = address(0);
    string public data;
    bool public removed = false;
    uint public paidEth = 0;

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

    function getLengthInSeconds() public view returns (uint) {
        return (endTimestamp - startTimestamp);
    }

    function setBooker(address _booker) public {
        booker = _booker;
    }

    function setData(string memory _data) public {
        data = _data;
    }

    function setPaidEth(uint _paidEth) public {
        paidEth = _paidEth;
    }

    function isValid() public view returns (bool) {
        return id != InvalidId;
    }
}

contract SceneSchedulerFields {
    FeeCache public fee;

    constructor() {
        fee = new FeeCache();
    }
}

contract SceneScheduler is Ownable {
    SceneSchedulerFields internal f;
    
    Schedule [] schedules;
    function getScheduleDetail(uint id) public view returns (
        uint startTimestamp,
        uint endTimestamp,
        address booker,
        string memory data,
        uint paidEth,
        bool removed
    ) {
        Schedule s = schedules[id];
        startTimestamp = s.startTimestamp();
        endTimestamp = s.endTimestamp();
        booker = s.booker();
        data = s.data();
        paidEth = s.paidEth();
        removed = s.removed();
    }

    mapping(uint => uint) scheduleMap; // each starting hour timpstamp => index in schedules
    uint constant NotReserved = 0; // value for representing not reserved in scheduleMap
    function getScheduleId(uint _startTimestamp) public view returns (uint) {
        require(_startTimestamp % HourInSeconds == 0, "_startTimestamp should point at the starting of each hour");
        return scheduleMap[_startTimestamp];
    }

    uint constant MinuteInSeconds = 60;
    uint constant HourInSeconds = MinuteInSeconds * 60;
    uint constant DayInSeconds = HourInSeconds * 24;

    uint private createScheduleLimitSeconds; // from present point only can create schedule within this value of seconds in the future
    function getCreateScheduleLimitSeconds() public view returns (uint) {
        return createScheduleLimitSeconds;
    }
    function setCreateScheduleLimitSeconds(uint newValue) public onlyOwner {
        createScheduleLimitSeconds = newValue;
    }

    uint private getMySchedulesLimitSeconds;
    function getChangeScheduleLimitSeconds() public view returns (uint) {
        return changeScheduleLimitSeconds;
    }
    function setChangeScheduleLimitSeconds(uint newValue) public onlyOwner {
        changeScheduleLimitSeconds = newValue;
    }

    uint private changeScheduleLimitSeconds;
    function getFeePerSecond() public view returns (uint256 weiPerSecond) {
        return f.fee().getFeePerSecond();
    }
    function getFeePerMinute() public view returns (uint256 weiPerMinute) {
        return f.fee().getFeePerMinute();
    }

    uint constant PermissionAdmin = 0xffffffffffffffffffffffffffffffff;
    uint constant PermissionReadOthersSchedule = 0x1;
    uint constant PermissionRemoveOthersSchedule = 0x2;
    mapping(address => uint) permissionMap;

    constructor() payable {
        f = new SceneSchedulerFields();
        
        // add dummy info at the index=0, to use index 0 as NotReserved
        Schedule dummySched = new Schedule(0, 0, 0, address(0), "");
        schedules.push(dummySched);
        createScheduleLimitSeconds = DayInSeconds * 30; // 30 days
        getMySchedulesLimitSeconds = DayInSeconds * 7; // 7 days
        changeScheduleLimitSeconds = DayInSeconds; // 24 hours
        
        permissionMap[owner()] = PermissionAdmin; // grant all the permission to owner
    }
    receive() external payable {} // need payable keyword to get ETH
    
    function setFee(uint newFeeWeiPerSecond) public onlyOwner {
        f.fee().setFee(newFeeWeiPerSecond);
    }
    function getFeePerHour() public view returns (uint256 weiPerHour) {
        return f.fee().getFeePerHour();
    }
    function getFeePerDay() public view returns (uint256 weiPerDay) {
        return f.fee().getFeePerDay();
    }


    function getTimestampNow() public view returns (uint) {
        return block.timestamp;
    }

    function balance() public view onlyOwner returns (uint) {        
        return address(this).balance;
    }
    
    function getEarliestStartingHourTimestampWithPresentTimestamp() public view returns (uint earliestStartTime, uint timestampNow) {
        timestampNow = block.timestamp;
        uint remainder = timestampNow % HourInSeconds;
        earliestStartTime = timestampNow - remainder + HourInSeconds;
    }

    function getEarliestStartingHourTimestamp() public view returns (uint earliestStartTimestamp) {
        (earliestStartTimestamp, ) = getEarliestStartingHourTimestampWithPresentTimestamp();
    }

    function _getSchedules(uint searchStartTimestamp, uint searchEndTimestamp, bool onlyMine) internal view returns (Schedule[] memory searchedSchedules) {        
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
                Schedule s = schedules[scheduleIndex];
                if (onlyMine == false || s.booker() == msg.sender) {
                    myScheduleStartings[count] = t;
                    count++;
                    t = s.endTimestamp() - HourInSeconds;
                }                
            }
        }
   
        searchedSchedules = new Schedule[](count);

        // fill the array for return
        for (uint i = 0; i < count; i++) {
            uint t = myScheduleStartings[i];
            uint scheduleIndex = scheduleMap[t];
            searchedSchedules[i] = schedules[scheduleIndex];
        }

        return searchedSchedules;
    }

    function _getScheduleIds(uint searchStartTimestamp, uint searchEndTimestamp, bool onlyMine) public view returns (uint[] memory) {
        Schedule [] memory retSchedules = _getSchedules(searchStartTimestamp, searchEndTimestamp, onlyMine);
        uint [] memory ids = new uint[](retSchedules.length);
        for(uint i=0; i < ids.length; i++) {
            ids[i] = retSchedules[i].id();
        }
        return ids;
    }

    function getSchedules(uint searchStartTimestamp, uint searchEndTimestamp) public view returns (Schedule[] memory) {
        return _getSchedules(searchStartTimestamp, searchEndTimestamp, false);
    }

    function getScheduleIds(uint searchStartTimestamp, uint searchEndTimestamp) public view returns (uint[] memory) {
        return _getScheduleIds(searchStartTimestamp, searchEndTimestamp, false);
    }

    function getMySchedules(uint searchStartTimestamp, uint searchEndTimestamp) public view returns (Schedule[] memory) {
        return _getSchedules(searchStartTimestamp, searchEndTimestamp, true);
    }
    function getMyScheduleIds(uint searchStartTimestamp, uint searchEndTimestamp) public view returns (uint[] memory) {
        return _getScheduleIds(searchStartTimestamp, searchEndTimestamp, true);
    }

    function getPresentScheduleStartingTimestamp() public view returns (uint) {
        uint timestampNow = block.timestamp;        
        return timestampNow - (timestampNow % HourInSeconds);
    }

    function getScheduleNow() public view 
        returns (
            bool scheduleExist, 
            uint id,
            uint startTimestamp,
            uint endTimestamp,
            address booker,
            string memory data,
            uint paidEth,
            bool removed) 
    {
        uint presentScheduleStartTimestamp = getPresentScheduleStartingTimestamp();
        uint scheduleIndex = scheduleMap[presentScheduleStartTimestamp];
        if (NotReserved != scheduleMap[presentScheduleStartTimestamp]) {
            Schedule s = schedules[scheduleIndex];
            return (
                true, 
                s.id(),
                s.startTimestamp(),
                s.endTimestamp(),
                s.booker(),
                s.data(),
                s.paidEth(),
                s.removed()
            );
        }
            
        scheduleExist = false;
    }

    function createSchedule(uint _startTimestamp, uint _endTimestamp, string memory _data) public payable returns (uint newScheduleId) {
        Schedule newSchedule = _createSchedule(_startTimestamp, _endTimestamp, _data);

        // check sent ETH amount        
        uint totalFee = newSchedule.getLengthInSeconds() * f.fee().getFeePerSecond();
        if (msg.value < totalFee)
            revert("ETH amount is not enough to create schedule for given period.");
        else if (msg.value > totalFee)
            revert("ETH amount is too much to create schedule for given period.");

        (bool ret, ) = payable(address(this)).call{value: msg.value}("");
        require(ret, "Failed to send ETH to contract");
        newSchedule.setPaidEth(msg.value);

        return newSchedule.id();
    }

    function _createSchedule(uint _startTimestamp, uint _endTimestamp, string memory _data) internal returns (Schedule newSched) {
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

        // check if time slot is avaiable
        for (uint t = _startTimestamp; t < _endTimestamp ; t += HourInSeconds) {
            require(NotReserved == scheduleMap[t], "There's already reserved time.") ;
        }

        // execute creating schedule
        newSched = new Schedule(schedules.length, _startTimestamp, _endTimestamp, msg.sender, _data);
        schedules.push(newSched);
        require(schedules[schedules.length-1].id() == schedules.length-1, "new schedule id should be the same as the index in schedules array.");

        for (uint t = _startTimestamp; t < _endTimestamp ; t += HourInSeconds) {
            scheduleMap[t] = newSched.id();
        }
        
        return newSched;
    }

    function getPermission() internal view returns (uint) {
        return permissionMap[msg.sender];
    }

    function hasPermission(uint permission) internal view returns (bool) {
        return getPermission() & permission == permission;
    }

    function modifySchedule(uint scheduleIndex, uint newStartTimestamp, uint newEndTimestamp, string memory newData) 
        public payable returns (Schedule newSchedule)
    {
        Schedule removedSchedule = _removeSchedule(scheduleIndex);
        newSchedule = _createSchedule(newStartTimestamp, newEndTimestamp, newData);
        
        // check sent ETH amount
        uint feeForCreate = newSchedule.getLengthInSeconds() * f.fee().getFeePerSecond();
        if (feeForCreate > removedSchedule.paidEth()) {
            uint ethToPay = feeForCreate - removedSchedule.paidEth();
            if (msg.value < ethToPay)
                revert("ETH amount is not enough to create schedule for given period.");
            else if (msg.value > ethToPay)
                revert("ETH amount is too much to create schedule for given period.");

            (bool ret, ) = payable(address(this)).call{value: ethToPay}("");
            require(ret, "Failed to send ETH to contract");
        }
        else if (feeForCreate < removedSchedule.paidEth()) {
            uint ethToRefund = removedSchedule.paidEth() - feeForCreate;
            (bool ret, ) = payable(msg.sender).call{value: ethToRefund}("");
            require(ret, "Failed to send back ETH to booker");            
        }
        newSchedule.setPaidEth(feeForCreate);
        removedSchedule.setPaidEth(0);
    }

    function removeSchedule(uint scheduleId) public payable {
        Schedule removedSchedule = _removeSchedule(scheduleId);        
        (bool ret, ) = payable(msg.sender).call{value: removedSchedule.paidEth()}("");
        require(ret, "Failed to send back ETH to booker");
        removedSchedule.setPaidEth(0);
    }

    function _removeSchedule(uint scheduleIndex) internal returns (Schedule) {
        Schedule s = schedules[scheduleIndex];
        require(s.isValid(), "You can remove only valid schedules.");
        require(s.removed() == false, "You can't remove the schedule already removed.");
        require(msg.sender == s.booker() || hasPermission(PermissionRemoveOthersSchedule), "No permission to remove given schedule.");
        uint nowTimestamp = block.timestamp;
        require(nowTimestamp < s.startTimestamp(), "schedule you want to remove should not be the past");
        if (hasPermission(PermissionRemoveOthersSchedule) == false)
            require(s.startTimestamp() - nowTimestamp > changeScheduleLimitSeconds, "You can't remove this schedule now.");

        for (uint t = s.startTimestamp(); t < s.endTimestamp(); t += HourInSeconds) {
            require(scheduleMap[t] == scheduleIndex, "The time is not occupied by this schedule.");
            scheduleMap[t] = NotReserved;
        }
        s.remove();

        return s;
    }
}