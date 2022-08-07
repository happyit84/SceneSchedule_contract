// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
//import "FeeCache.sol";
//import "ScheduleInfo.sol";

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
    string public data = "";
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

contract SceneScheduleFields {
    FeeCache public fee;

    ScheduleInfo [] public schedules;
    function getSchedule(uint id) public view returns (ScheduleInfo) {return schedules[id];}
    function getScheduleCount() public view returns (uint) {return schedules.length;}
    function addSchedule(ScheduleInfo newSchedule) public {schedules.push(newSchedule);}
    
    mapping(uint => uint) internal scheduleMap; // each starting hour timpstamp => index in schedules
    function getScheduleId(uint startTimestamp) public view returns (uint scheduleId) {return scheduleMap[startTimestamp];}
    function setScheduleMap(uint startTimestamp, uint id) public {scheduleMap[startTimestamp] = id;}
        
    uint constant public NotReserved = 0; // value for representing not reserved in scheduleMap
    uint constant public MinuteInSeconds = 60;
    uint constant public HourInSeconds = MinuteInSeconds * 60;
    uint constant public DayInSeconds = HourInSeconds * 24;

    uint public limitSecondsCreateSchedule; // from present point only can create schedule within this value of seconds in the future
    function setLimitSecondsCreateSchedule(uint v) public {limitSecondsCreateSchedule = v;}

    uint public limitSecondsGetMySchedules;
    function setLimitSecondsGetMySchedules(uint v) public {limitSecondsGetMySchedules = v;}
    
    uint public limitSecondsChangeSchedule;
    function setLimitSecondsChangeSchedule(uint v) public {limitSecondsChangeSchedule = v;}
    
    constructor() {
        fee = new FeeCache();

        // add dummy info at the index=0, to use index 0 as NotReserved
        ScheduleInfo dummyInfo = new ScheduleInfo(0, 0, 0, address(0), "");
        schedules.push(dummyInfo);

        limitSecondsCreateSchedule = DayInSeconds * 30; // 30 days
        limitSecondsGetMySchedules = DayInSeconds * 7; // 7 days
        limitSecondsChangeSchedule = DayInSeconds; // 24 hours
    }    
}

contract SceneSchedulerInternalLayer {
    SceneScheduleFields public f;

    mapping(address => uint) public permissionMap;
    uint constant public PermissionAdmin = 0xffffffffffffffffffffffffffffffff;
    uint constant public PermissionRemoveOthersSchedule = 0x1;
    function getPermission(address key) public view returns (uint) {return permissionMap[key];}
    function setPermission(address key, uint permission) public {permissionMap[key] = permission;}


    constructor(address owner) {
        //f.setPermission(owner, f.PermissionAdmin());
        setPermission(owner, PermissionAdmin);
    }

    function _getSchedules(uint searchStartTimestamp, uint searchEndTimestamp, bool onlyMine) public view returns (ScheduleInfo[] memory searchedSchedules) {        
        require(searchStartTimestamp % f.HourInSeconds() == 0, "searchStartTimpstamp should point at the starting of an hour.");
        if (searchEndTimestamp == 0)
            searchEndTimestamp = searchStartTimestamp + f.DayInSeconds()*7;
        require(searchEndTimestamp % f.HourInSeconds() == 0, "searchEndTimestamp should point at the starting of an hour.");
        require(searchStartTimestamp < searchEndTimestamp, "searchStarTimestamp should be earlier than searchEndTimestamp.");
        require(searchEndTimestamp - searchStartTimestamp <= f.limitSecondsGetMySchedules(), "Search range is too broad. searchEndTimestamp - searchStartTimestamp should not be greater than 7 days.");

        uint cacheSize = (searchEndTimestamp - searchStartTimestamp) / f.HourInSeconds() + 1;
        uint [] memory myScheduleStartings = new uint[](cacheSize);
        uint count = 0;
        // calculate size of return array and cache the starting time of my schedules
        for (uint t = searchStartTimestamp; t < searchEndTimestamp; t += f.HourInSeconds()) {
            uint scheduleIndex = f.getScheduleId(t); 
            if (scheduleIndex != f.NotReserved()) {
                ScheduleInfo info = f.getSchedule(scheduleIndex);
                if (onlyMine == false || info.booker() == msg.sender) {
                    myScheduleStartings[count] = t;
                    count++;
                    t = info.endTimestamp() - f.HourInSeconds();
                }                
            }
        }
   
        searchedSchedules = new ScheduleInfo[](count);

        // fill the array for return
        for (uint i = 0; i < count; i++) {
            uint t = myScheduleStartings[i];
            uint scheduleIndex = f.getScheduleId(t);
            searchedSchedules[i] = f.getSchedule(scheduleIndex);
        }

        return searchedSchedules;
    }

    function _getScheduleIds(uint searchStartTimestamp, uint searchEndTimestamp, bool onlyMine) public view returns (uint[] memory scheduleIds) {
        ScheduleInfo[] memory resultSchedules = _getSchedules(searchStartTimestamp, searchEndTimestamp, onlyMine);
        scheduleIds = new uint[](resultSchedules.length);
        for(uint i=0; i < scheduleIds.length; i++)
            scheduleIds[i] = resultSchedules[i].id();
    }

    function _createSchedule(uint _startTimestamp, uint _endTimestamp, string memory _data, bool isOwner) public returns (ScheduleInfo info) {
        // check if timestamp is hour base
        // check start time
        if (isOwner == false)
            require(_startTimestamp >= block.timestamp, "_startTimestamp should not be past time.");
        require(_startTimestamp % f.HourInSeconds() == 0, "_startTimestamp should point at starting of each hour.");
        uint timestampLimit = getEarliestStartingHourTimestamp() + f.limitSecondsCreateSchedule();
        require(_startTimestamp < timestampLimit, "Too much future time. Check the limit of seconds with getCreateScheduleLimitSeconds()");

        // check end time
        if (_endTimestamp == 0)
            _endTimestamp = _startTimestamp + f.HourInSeconds();
        else
            require(_endTimestamp % f.HourInSeconds() == 0, "_endTimestamp should point at the starting of each hour.");
        require(_startTimestamp < _endTimestamp, "_startTimestamp should be earlier than _endTimpstamp.");

        // check if time slot is avaiable
        for (uint t = _startTimestamp; t < _endTimestamp ; t += f.HourInSeconds()) {
            require(f.NotReserved() == f.getScheduleId(t), "There's already reserved time.") ;
        }

        // execute creating schedule
        info = new ScheduleInfo(f.getScheduleCount(), _startTimestamp, _endTimestamp, msg.sender, _data);
        f.addSchedule(info);
        uint scheduleCount = f.getScheduleCount();
        uint expectedNewScheduleId = scheduleCount - 1;
        require(f.getSchedule(expectedNewScheduleId).id() == expectedNewScheduleId, "new schedule id should be the same as the index in schedules array.");

        for (uint t = _startTimestamp; t < _endTimestamp ; t += f.HourInSeconds()) {
            f.setScheduleMap(t, info.id());
        }
        
        return info;
    }
    
    function _removeSchedule(uint scheduleIndex) public returns (ScheduleInfo) {
        ScheduleInfo info = f.getSchedule(scheduleIndex);
        require(info.isValid(), "You can remove only valid schedules.");
        require(info.removed() == false, "You can't remove the schedule already removed.");
        require(msg.sender == info.booker() || hasPermission(f.PermissionRemoveOthersSchedule()), "No permission to remove given schedule.");
        uint nowTimestamp = block.timestamp;
        require(nowTimestamp < info.startTimestamp(), "schedule you want to remove should not be the past");
        if (hasPermission(f.PermissionRemoveOthersSchedule()) == false)
            require(info.startTimestamp() - nowTimestamp > f.limitSecondsCreateSchedule(), "You can't remove this schedule now.");

        for (uint t = info.startTimestamp(); t < info.endTimestamp(); t += f.HourInSeconds()) {
            require(f.getScheduleId(t) == scheduleIndex, "The time is not occupied by this schedule.");
            f.setScheduleMap(t, f.NotReserved());
        }
        info.remove();

        return info;
    }

    function getPermission() internal view returns (uint) {
        return f.getPermission(msg.sender);
    }

    function hasPermission(uint permission) internal view returns (bool) {
        return getPermission() & permission == permission;
    }


    function getEarliestStartingHourTimestampWithPresentTimestamp() public view returns (uint earliestStartTime, uint timestampNow) {
        timestampNow = block.timestamp;
        uint remainder = timestampNow % f.HourInSeconds();
        earliestStartTime = timestampNow - remainder + f.HourInSeconds();
    }

    function getEarliestStartingHourTimestamp() public view returns (uint earliestStartTimestamp) {
        (earliestStartTimestamp, ) = getEarliestStartingHourTimestampWithPresentTimestamp();
    }
}

contract SceneScheduler is Ownable {
    SceneSchedulerInternalLayer internal l;

    constructor() payable {    
        l = new SceneSchedulerInternalLayer(owner());
    }

    receive() external payable {} // need payable keyword to get ETH

    function f() public view returns (SceneScheduleFields) {return l.f();}

    function getScheduleMapValue(uint keyTimestamp) public view onlyOwner returns (uint) {
        return f().getScheduleId(keyTimestamp);
    }

    function getTimestampNow() public view returns (uint) {
        return block.timestamp;
    }

    function balance() public view onlyOwner returns (uint) {        
        return address(this).balance;
    }
    
    function setFee(uint newFeeWeiPerSecond) public onlyOwner {
        f().fee().setFee(newFeeWeiPerSecond);
    }

    function isOwner() public view returns (bool) {
        return owner() == msg.sender;
    }

    function getLimitSecondsCreateSchedule() public view returns (uint) {
        return f().limitSecondsCreateSchedule();
    }
    function setLimitSecondsCreateSchedule(uint newValue) public onlyOwner {
        f().setLimitSecondsCreateSchedule(newValue);
    }

    function getLimitSecondsChangeSchedule() public view returns (uint) {
        return f().limitSecondsChangeSchedule();
    }
    function setLimitSecondsChangeSchedule(uint newValue) public onlyOwner {
        f().setLimitSecondsChangeSchedule(newValue);
    }

    function getFeePerSecond() public view returns (uint256 weiPerSecond) {
        return f().fee().getFeePerSecond();
    }

    function getFeePerMinute() public view returns (uint256 weiPerMinute) {
        return f().fee().getFeePerMinute();
    }

    function getFeePerHour() public view returns (uint256 weiPerHour) {
        return f().fee().getFeePerHour();
    }
    
    function getFeePerDay() public view returns (uint256 weiPerDay) {
        return f().fee().getFeePerDay();
    }

    function getNotReserved() external view returns (uint) {
        return f().NotReserved();
    }

    function getSchedules(uint searchStartTimestamp, uint searchEndTimestamp) public view returns (ScheduleInfo[] memory) {
        return l._getSchedules(searchStartTimestamp, searchEndTimestamp, false);
    }

    function getScheduleIds(uint searchStartTimestamp, uint searchEndTimestamp) public view returns (uint[] memory ids) {
        return l._getScheduleIds(searchStartTimestamp, searchEndTimestamp, false);
    }

    function getMySchedules(uint searchStartTimestamp, uint searchEndTimestamp) public view returns (ScheduleInfo[] memory) {
        return l._getSchedules(searchStartTimestamp, searchEndTimestamp, true);
    }
    
    function getMyScheduleIds(uint searchStartTimestamp, uint searchEndTimestamp) public view returns (uint[] memory ids) {
        return l._getScheduleIds(searchStartTimestamp, searchEndTimestamp, true);
    }

    function getPresentScheduleStartingTimestamp() public view returns (uint) {
        uint timestampNow = block.timestamp;        
        return timestampNow - (timestampNow % f().HourInSeconds());
    }

    function getSchedule(uint id) public view 
        returns (
            uint startTimestamp,
            uint endTimestamp,
            address booker,
            string memory data,
            uint paidEth,
            bool removed
        )
    {
        ScheduleInfo info = f().getSchedule(id);
        startTimestamp = info.startTimestamp();
        endTimestamp = info.endTimestamp();
        booker = info.booker();
        data = info.data();
        paidEth = info.paidEth();
        removed = info.removed();
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
            bool removed
        )
    {
        uint presentScheduleStartTimestamp = getPresentScheduleStartingTimestamp();
        uint scheduleIndex = f().getScheduleId(presentScheduleStartTimestamp);
        if (f().NotReserved() != f().getScheduleId(presentScheduleStartTimestamp))
        {
            ScheduleInfo info = f().getSchedule(scheduleIndex);
            scheduleExist = true;
            id = info.id();
            startTimestamp = info.startTimestamp();
            endTimestamp = info.endTimestamp();
            booker = info.booker();
            data = info.data();
            paidEth = info.paidEth();
            removed = info.removed();
        }
        else
            scheduleExist = false;
    }

    function getScheduleIndex(uint _startTimestamp) public view returns (uint) {
        require(_startTimestamp % f().HourInSeconds() == 0, "_startTimestamp should point at the starting of each hour");
        return f().getScheduleId(_startTimestamp);
    }

    function createSchedule(uint _startTimestamp, uint _endTimestamp, string memory _data) public payable returns (ScheduleInfo createdScheduleInfo) {
        createdScheduleInfo = l._createSchedule(_startTimestamp, _endTimestamp, _data, isOwner());

        // check sent ETH amount        
        uint totalFee = createdScheduleInfo.getLengthInSeconds() * f().fee().getFeePerSecond();
        if (msg.value < totalFee)
            revert("ETH amount is not enough to create schedule for given period.");
        else if (msg.value > totalFee)
            revert("ETH amount is too much to create schedule for given period.");

        (bool ret, ) = payable(address(this)).call{value: msg.value}("");
        require(ret, "Failed to send ETH to contract");
        createdScheduleInfo.setPaidEth(msg.value);
    }

    function modifySchedule(uint scheduleIndex, uint newStartTimestamp, uint newEndTimestamp, string memory newData) 
        public payable returns (ScheduleInfo newScheduleInfo)
    {
        ScheduleInfo removedScheduleInfo = l._removeSchedule(scheduleIndex);
        newScheduleInfo = l._createSchedule(newStartTimestamp, newEndTimestamp, newData, isOwner());
        
        // check sent ETH amount
        uint feeForCreate = newScheduleInfo.getLengthInSeconds() * f().fee().getFeePerSecond();
        if (feeForCreate > removedScheduleInfo.paidEth()) {
            uint ethToPay = feeForCreate - removedScheduleInfo.paidEth();
            if (msg.value < ethToPay)
                revert("ETH amount is not enough to create schedule for given period.");
            else if (msg.value > ethToPay)
                revert("ETH amount is too much to create schedule for given period.");

            (bool ret, ) = payable(address(this)).call{value: ethToPay}("");
            require(ret, "Failed to send ETH to contract");
        }
        else if (feeForCreate < removedScheduleInfo.paidEth()) {
            uint ethToRefund = removedScheduleInfo.paidEth() - feeForCreate;
            (bool ret, ) = payable(msg.sender).call{value: ethToRefund}("");
            require(ret, "Failed to send back ETH to booker");            
        }
        newScheduleInfo.setPaidEth(feeForCreate);
        removedScheduleInfo.setPaidEth(0);
    }

    function removeSchedule(uint scheduleId) public payable {
        ScheduleInfo removedScheduleInfo = l._removeSchedule(scheduleId);        
        (bool ret, ) = payable(msg.sender).call{value: removedScheduleInfo.paidEth()}("");
        require(ret, "Failed to send back ETH to booker");
        removedScheduleInfo.setPaidEth(0);
    }
}