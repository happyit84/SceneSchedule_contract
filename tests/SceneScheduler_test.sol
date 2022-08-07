// SPDX-License-Identifier: GPL-3.0
        
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
import "../SceneScheduler.sol";

// File name has to end with '_test.sol', this file can contain more than one testSuite contracts
contract TestSceneSchedule is SceneScheduler {

    uint createdScheduleIndex;
    Schedule [] testScheds;
/*
    /// 'beforeAll' runs before all other tests
    /// More special functions are: 'beforeEach', 'beforeAll', 'afterEach' & 'afterAll'
    function beforeAll() public {        
        // <instantiate contract>
        Assert.equal(uint(1), uint(1), "1 should be equal to 1");
        //sceneSchedule = new SceneSchedule();
        createdScheduleIndex = NotReserved;
    }

    function beforeEach() public {

    }

    function afterAll() public {

    }

    function afterEach() public {

    }

    function testFeeCache() public {
        //FeeCache fee = new FeeCache();
        Assert.equal(getFeePerSecond(), uint256(1), "Initial Fee per second should be 1 wei.");
        setFee(10);
        Assert.equal(getFeePerSecond(), uint256(10), "Fee per second should be 10 wei.");
        Assert.equal(getFeePerMinute(), uint256(600), "Fee per minute should be 600 wei.");
        Assert.equal(getFeePerHour(), uint256(36000), "Fee per hour should be 36000 wei.");
        Assert.equal(getFeePerDay(), uint256(864000), "Fee per day should be 864000 wei.");
        setFee(1);
        Assert.equal(getFeePerSecond(), uint256(1), "Fee per second should be 10 wei.");
        Assert.equal(getFeePerMinute(), uint256(60), "Fee per minute should be 600 wei.");
        Assert.equal(getFeePerHour(), uint256(3600), "Fee per hour should be 36000 wei.");
        Assert.equal(getFeePerDay(), uint256(86400), "Fee per day should be 864000 wei.");
    }

    function checkSuccess() public {
        // Use 'Assert' methods: https://remix-ide.readthedocs.io/en/latest/assert_library.html
        Assert.ok(2 == 2, 'should be true');
        Assert.greaterThan(uint(2), uint(1), "2 should be greater than to 1");
        Assert.lesserThan(uint(2), uint(3), "2 should be lesser than to 3");
    }

    function checkSuccess2() public pure returns (bool) {
        // Use the return value (true or false) to test the contract
        return true;
    }
    
    function checkFailure() public {
        Assert.notEqual(uint(1), uint(2), "1 should not be equal to 2");
    }
*/
    /// Custom Transaction Context: https://remix-ide.readthedocs.io/en/latest/unittesting.html#customization
    /// #sender: account-0
    /// #value: 7200
    function testCreateSchedule() public payable {
        // account index varies 0-9, value is in wei
        Assert.equal(msg.sender, TestsAccounts.getAccount(0), "Invalid sender");
        Assert.equal(msg.value, 7200, "Invalid value");

        // create schedule
        uint timestampNow = block.timestamp;
        uint remainder = timestampNow % 3600;
        uint earliestStartTime = timestampNow - remainder + 3600;
        uint earliestEndTime = earliestStartTime + 3600*2;

        string memory data = "...";
        uint newSchedId = createSchedule(earliestStartTime, earliestEndTime, data);
        Schedule newSched = f.getSchedule(newSchedId);
        testScheds.push(newSched);
        Assert.ok(newSched.id() != NotReserved, "scheduleIndex != sceneSchedule.getNotReserved()");

        // test getMySchedule
        Schedule[] memory mySchedules = getMySchedules(earliestStartTime - 3600, earliestStartTime + 3600 * 4);
        Schedule s = mySchedules[0];
        Assert.equal(mySchedules.length, 1, "Length of schedule array returned from getMySchedule() should be 1.");
        Assert.ok(s.startTimestamp() == earliestStartTime, "The start timestamp of the schedule retured by getMySchedules() is different from the expected.");
        Assert.equal(s.endTimestamp(), earliestEndTime, "The end timestamp of the schdule returned by getMySchedules() is different from the expected.");        
    }
/*
    /// #sender: account-1
    function testGetSheduleWithOtherAccount1() public {
        Assert.equal(msg.sender, TestsAccounts.getAccount(1), "Invalid sender");

        // test getMySchedule
        ScheduleInfo testInfo = testScheds[testScheds.length-1];
        ScheduleInfo[] memory mySchedules = getMySchedules(testInfo.startTimestamp(), testInfo.startTimestamp() + 3600 * 4);
        Assert.equal(mySchedules.length, 0, "Length of schedule array returned from getMySchedules() should be 0.");
    }

    /// #sender: account-1
    function testGetSheduleWithOtherAccount2() public {
        Assert.equal(msg.sender, TestsAccounts.getAccount(1), "Invalid sender");

        // test getSchedules
        ScheduleInfo testInfo = testScheds[testScheds.length-1];
        ScheduleInfo[] memory schedules = getSchedules(testInfo.startTimestamp(), testInfo.startTimestamp() + 3600 * 4);
        Assert.equal(schedules.length, 1, "Length of schedule array returned from getSchedules() should be 1.");
        Assert.equal(testInfo.startTimestamp(), schedules[0].startTimestamp(), "The start timestamp of the schedule retured by getSchedules() is different from the expected.");
        Assert.equal(testInfo.endTimestamp(), schedules[0].endTimestamp(), "The end timestamp of the schdule returned by getSchedules() is different from the expected.");
        Assert.equal(schedules[0].booker(), address(0), "The booker of other's schedule should be invisible.");
        Assert.equal(schedules[0].data(), "", "The data of other's schedule should be invisible.");
    }

    /// #sender: account-0
    function testGetMyShedule2_1() public {
        Assert.equal(msg.sender, TestsAccounts.getAccount(0), "Invalid sender");

        // test getMySchedule
        ScheduleInfo testInfo = testScheds[testScheds.length-1];
        ScheduleInfo[] memory mySchedules = getMySchedules(testInfo.startTimestamp(), testInfo.startTimestamp() + 3600 * 4);
        Assert.equal(mySchedules.length, 1, "Length of schedule array returned from getMySchedules() should be 1.");
        Assert.equal(testInfo.startTimestamp(), mySchedules[0].startTimestamp(), "The start timestamp of the schedule retured by getSchedules() is different from the expected.");
        Assert.equal(testInfo.endTimestamp(), mySchedules[0].endTimestamp(), "The end timestamp of the schdule returned by getSchedules() is different from the expected.");
        Assert.equal(mySchedules[0].booker(), msg.sender, "The booker of other's schedule should be invisible.");
        Assert.equal(mySchedules[0].data(), testInfo.data(), "The data of other's schedule should be invisible.");
    }
    
    /// #sender: account-0
    function testGetMySchedule2_2() public {
        Assert.equal(msg.sender, TestsAccounts.getAccount(0), "Invalid sender");

        // test getSchedules
        ScheduleInfo testInfo = testScheds[testScheds.length-1];
        ScheduleInfo[] memory schedules = getSchedules(testInfo.startTimestamp(), testInfo.startTimestamp() + 3600 * 4);
        Assert.equal(schedules.length, 1, "Length of schedule array returned from getSchedules() should be 1.");
        Assert.equal(testInfo.startTimestamp(), schedules[0].startTimestamp(), "The start timestamp of the schedule retured by getSchedules() is different from the expected.");
        Assert.equal(testInfo.endTimestamp(), schedules[0].endTimestamp(), "The end timestamp of the schdule returned by getSchedules() is different from the expected.");
        Assert.equal(schedules[0].booker(), msg.sender, "The booker of other's schedule should be invisible.");
        Assert.equal(schedules[0].data(), testInfo.data(), "The data of other's schedule should be invisible.");
    }

    /// #sender: account-1
    function testGetscheduleNow() public {
        Assert.equal(msg.sender, TestsAccounts.getAccount(1), "Invalid sender");
        (bool scheduleExist, ScheduleInfo presentScheduleInfo) = getScheduleNow();
        if (scheduleExist)
        {
            ScheduleInfo testInfo = testScheds[testScheds.length-1];
            Assert.ok(presentScheduleInfo.startTimestamp() == testInfo.startTimestamp() &&
                    presentScheduleInfo.endTimestamp() == testInfo.endTimestamp() &&
                    presentScheduleInfo.booker() == testInfo.booker() &&
                    keccak256(bytes(presentScheduleInfo.data())) == keccak256(bytes(testInfo.data())), "Present schedule info is wrong.");
        }   
    }
*/
    /// #sender: account-0
    /// #value: 0
    function testModifySchedule() public payable {
        Assert.equal(msg.sender, TestsAccounts.getAccount(0), "Invalid sender");
        Assert.equal(msg.value, 0, "Invalid value");

        Schedule testInfo = testScheds[testScheds.length-1];
        uint newStartTime = testInfo.startTimestamp() + 3600;
        uint newEndTime = testInfo.endTimestamp() + 3600;
        Schedule modifiedSched = modifySchedule(testInfo.id(), newStartTime, newEndTime, testInfo.data());
        testScheds.push(modifiedSched);
        Schedule[] memory mySchedules = getMySchedules(modifiedSched.startTimestamp(), modifiedSched.endTimestamp());

        Assert.equal(mySchedules[0].id(), modifiedSched.id(), "wrong id of modified schedule");
        Assert.equal(mySchedules[0].startTimestamp(), modifiedSched.startTimestamp(), "wrong startTimestamp of modified schedule");
        Assert.equal(mySchedules[0].endTimestamp(), modifiedSched.endTimestamp(), "wrong endTimestamp of modifed schedule");
    }

    /// #sender: account-0
    /// #value: 3600
    function testModifyScheduleWithMoreTime() public payable {
        Assert.equal(msg.sender, TestsAccounts.getAccount(0), "Invalid sender");
        Assert.equal(msg.value, 3600, "Invalid value");

        Schedule testInfo = testScheds[testScheds.length-1];
        uint newStartTime = testInfo.startTimestamp() + 3600;
        uint newEndTime = testInfo.endTimestamp() + 3600*2;
        Schedule modifiedSched = modifySchedule(testInfo.id(), newStartTime, newEndTime, testInfo.data());
        testScheds.push(modifiedSched);
        Schedule[] memory mySchedules = getMySchedules(modifiedSched.startTimestamp(), modifiedSched.endTimestamp());
        Assert.equal(mySchedules[0].id(), modifiedSched.id(), "wrong id of modified schedule");
        Assert.equal(mySchedules[0].startTimestamp(), newStartTime, "wrong startTimestamp of modified schedule");
        Assert.equal(mySchedules[0].endTimestamp(), newEndTime, "wrong endTimestamp of modifed schedule");
    }

    /// #sender: account-0
    /// #value: 0
    function testModifyScheduleLessTime() public payable {
        Assert.equal(msg.sender, TestsAccounts.getAccount(0), "Invalid sender");
        Assert.equal(msg.value, 0, "Invalid value");

        uint balanceBefore = address(msg.sender).balance;

        Schedule testInfo = testScheds[testScheds.length-1];
        uint newStartTime = testInfo.startTimestamp() + 3600;
        uint newEndTime = testInfo.endTimestamp();
        Schedule modifiedSched = modifySchedule(testInfo.id(), newStartTime, newEndTime, testInfo.data());
        testScheds.push(modifiedSched);
        Schedule[] memory mySchedules = getMySchedules(modifiedSched.startTimestamp(), modifiedSched.endTimestamp());
        Assert.equal(mySchedules[0].id(), modifiedSched.id(), "wrong id of modified schedule");
        Assert.equal(mySchedules[0].startTimestamp(), newStartTime, "wrong startTimestamp of modified schedule");
        Assert.equal(mySchedules[0].endTimestamp(), newEndTime, "wrong endTimestamp of modifed schedule");

        uint balanceAfter = address(msg.sender).balance;
        Assert.equal(balanceBefore + 3600, balanceAfter, "Sender's balance is not the same as expected.");
    }

    /// #sender: account-0
    /// #value: 3600
    function testModifyScheduleWithOtherAccount() public payable {
        // fail test can't be done.
    }

    /// #sender: account-0
    /// #value: 0
    function testRemoveSchedule() public payable {
        Assert.equal(msg.sender, TestsAccounts.getAccount(0), "Invalid sender");
        Assert.equal(msg.value, 0, "Invalid value");

        uint balanceBefore = address(msg.sender).balance;

        Schedule testInfo = testScheds[testScheds.length-1];
        //uint paidEth = testInfo.paidEth();
        removeSchedule(testInfo.id());
        //uint balanceBefore_clone = balanceBefore;
        //uint paidEth_clone = paidEth;
        uint balanceAfter = address(msg.sender).balance;
        //require(balanceBefore + 3600 == balanceAfter, "require - Sender's balance is not the same as expected.");*/
        Assert.ok(balanceBefore + 7200 == balanceAfter, "Sender's balance is not the same as expected.");

        Schedule[] memory mySchedules = getMySchedules(testInfo.startTimestamp(), testInfo.endTimestamp());
        Assert.ok(mySchedules.length == 0, "In time range of removed schedule, result of search should 0.");
    }

    

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /// FAIL TEST START!!! //////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /*function shouldFail_start() public {        
        Assert.ok(false, "=== Fail Test Start from here!!! ===");
    }

    /// #sender: account-1
    function shouldFail_setFeeNotByOwner() public {
        setFee(2);
        Assert.ok(true, "??");
    }

    /// #sender: account-1
    function shouldFail_setCreateScheduleLimitSeconds() public {
        setCreateScheduleLimitSeconds(1);
        Assert.ok(true, "??");
    }

    /// #sender: account-0
    /// #value: 3600
    function shouldFail_createScheduleOnReservedTime() public payable {
        // expected to fail when trying to create schedule on the time slot already reserved.
        string memory data = "...";
        createSchedule(scheduleInfo.startTimestamp(), scheduleInfo.endTimestamp(), data);
        Assert.ok(true, "??");
    }

    /// #sender: account-0
    /// #value: 3600
    function shouldFail_createScheduleOn31dayAfter() public payable {
        uint timestampNow = block.timestamp;
        uint remainder = timestampNow % 3600;
        uint earliestStartTime = timestampNow - remainder + 3600;
        uint days30 = 60 * 60 * 24 * 30;
        uint startTimeAfter30days = earliestStartTime + days30;
        createSchedule(startTimeAfter30days, 0, "");
        Assert.ok(true, "??");
    }*/
}
    