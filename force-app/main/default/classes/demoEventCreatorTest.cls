/**
 * demoEventCreatorTest - test class for demoEventCreator
 **/
@isTest
private class demoEventCreatorTest {
    @isTest
    static void demoEventCreatorTest() {
        // Create test Users
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
		List<User> tUsers = new List<User>();
        User u1 = new User(FirstName='Employee',LastName='1',EmployeeNumber='EE-9999901',Email='test1@example.com',Alias='test1',EmailEncodingKey='UTF-8',LanguageLocaleKey='en_US',LocaleSidKey='en_US',ProfileId=p.Id,TimeZoneSidKey='America/Los_Angeles', UserName='test1@mrhtestcode1.com');
        tUsers.add(u1);
        User u2 = new User(FirstName='Employee',LastName='2',EmployeeNumber='EE-9999902',Email='test2@example.com',Alias='test1',EmailEncodingKey='UTF-8',LanguageLocaleKey='en_US',LocaleSidKey='en_US',ProfileId=p.Id,TimeZoneSidKey='America/Los_Angeles', UserName='test2@mrhtestcode1.com');
        tUsers.add(u2);
        try {
            Database.SaveResult[] r0 = Database.insert(tUsers,false);
		} catch(DmlException e) {
    		System.debug('The following exception has occurred: ' + e.getMessage());
		}
        System.Debug('u1.Id: '+u1.Id);

        // Create test PersonAccounts
        RecordType paRT = [SELECT Id FROM RecordType WHERE Name = 'Person Account' and SObjectType = 'Account'];
		List<Account> tPAs = new List<Account>();
        Account p1 = new Account(FirstName='Employee',LastName='1',HealthCloudGA__SourceSystemId__pc='EE-9999901',RecordType=paRT);
		tPAs.add(p1);
        Account p2 = new Account(FirstName='Employee',LastName='2',HealthCloudGA__SourceSystemId__pc='EE-9999902',RecordType=paRT);
		tPAs.add(p2);
        try {
        	Database.SaveResult[] r1 = Database.insert(tPAs,false);
		} catch(DmlException e) {
    		System.debug('The following exception has occurred: ' + e.getMessage());
		}
        System.Debug('p1.Id: '+p1.Id);

        /**
         * Test demoEventCreator
         **/
		Test.startTest();
        // Test given a known employee
        Date tStartDate = Date.newInstance(2020, 5, 1);
        Date tEndDate = Date.newInstance(2020, 6, 1);
        List<demoEventCreator.employeesInputs> tInputs= new List<demoEventCreator.employeesInputs>();
        demoEventCreator.employeesInputs tInput = new demoEventCreator.employeesInputs();
        tInput.employeeNumber='EE-9999901';
        tInput.userId=u1.Id;
        tInput.runningUserId=u2.Id;
        tInput.startDate=tStartDate;
        tInput.endDate=tEndDate;
        tInput.numEvents=15;
        tInputs.add(tInput);
		demoEventCreator.demoEventCreator(tInputs);        

        /**
         * Validate
         * TO DO: Improve on the VERY light validation here which is just to achieve code coverage
         * 	for packaging for a demo component
         **/
        // Ensure at least 1 Event was created
        Event eVal = [SELECT Id FROM Event WHERE Subject LIKE 'Meeting %' LIMIT 1];
        System.assert(eVal != null); 
        // Ensure at least 1 EventRelation was created
        EventRelation erVal = [SELECT Id FROM EventRelation LIMIT 1];
        System.assert(erVal != null); 

        Test.stopTest();
    }
}
