/**
 * demoEventCreator - create Events and EventRelation records for demo purposes
 **/
global class demoEventCreator {
    /**
     * employeesInputs - Class for capturing input variables from the Flow
     */
    global class employeesInputs {
        // Employee number of the affected employee
        @InvocableVariable
        global String employeeNumber;

        // User.Id for the affected employee
        @InvocableVariable
        global String userId;

        // User.Id  for the running user
        //  They will be made the owner of Calendar entries to easily show the calendar without switching users
        @InvocableVariable
        global String runningUserId;

        // Start date for the search
        @InvocableVariable
        global Date startDate;

        // End date for the search
        @InvocableVariable
        global Date endDate;

        // Number of calendar events to create
        //  This will also be the Number of peersadded to the contact tracing graph since we're adding 1 peer/event
        @InvocableVariable
        global Integer numEvents;
    }

    @InvocableMethod(label='Create Sample Events for Contact Tracing')
    global static void demoEventCreator(List<employeesInputs> inputVars) {
        // Ensure input variables are set
        if (inputVars[0].userId == null || inputVars[0].runningUserId == null || inputVars[0].employeeNumber == null || inputVars[0].startDate == null || inputVars[0].endDate == null) {
            return;
        }
        /**
         * Initialize metrics
        **/
        // If not input, set defaults for number of events & desired number of peers
        if (inputVars[0].numEvents == null) {
            inputVars[0].numEvents = 10;
        }
        // Calculate metrics
        Integer numDays = inputVars[0].startDate.daysBetween(inputVars[0].endDate);
        Integer meetingsPerDay = (Integer)Math.ceil(Decimal.valueOf(inputVars[0].numEvents).divide(numDays,1));
        // Meeting length in hours
        Integer meetingLength = 1;
        // Time between meetings in hours
        Integer timeBetweenMeetings = 1;
        // Start of work day (hour)
        Integer startofDayHour = 9;
        Time startOfDay = Time.newInstance(startofDayHour,0,0,0);

        /** 
         * Create sample Events starting at startDate
         **/
        List<Event> sampleEvents = new List<Event>();
        Date thisDate = inputVars[0].startDate;
        Integer currentMeetingNum = 1;
        // Loop through the target days
        for (Integer i=0; i<numDays; i++) {
            // Create meetings on the current day starting at startOfDay
            DateTime thisStart = DateTime.newInstance(thisDate,startOfDay);
            for (Integer j=0; j<meetingsPerDay; j++) {
                // Generate the end time relative to  thisStart
                DateTime thisEnd = thisStart.addHours(meetingLength);
                // Create the event, owned by the affected employee (User)
                //  Peers will be added to this invite after Events are inserted
                String meetingTitle = 'Meeting '+currentMeetingNum;
                Event e = new Event(OwnerId=inputVars[0].runningUserId,Subject=meetingTitle,ActivityDateTime=thisStart,EndDateTime=thisEnd);
                sampleEvents.add(e);

                // Move to the next meeting number & time
                currentMeetingNum++;
                thisStart = thisStart.addHours(meetingLength + timeBetweenMeetings);
            }
            // Move to the next day
            // TO DO: skip weekends; also need to consider impact on / increment numDays
            // String dayOfWeek = dt.format('EEEE');  // Monday, Tuesday, Wednesday, ...
            thisDate = thisDate.addDays(1);
        }
        // Insert the sample Events
        try {
            Database.SaveResult[] eventResult = Database.insert(sampleEvents,false);
        } catch(DmlException e) {
            System.debug('The following exception has occurred: ' + e.getMessage());
        }
  
        /**
         * Create Attendees (EventRelations) for the sample events
         **/
        // Get a list of Contact EmployeeNumbers
        List<String> peerENums = new List<String>();                                                      
        for (Contact c : [SELECT HealthCloudGA__SourceSystemId__c FROM Contact WHERE HealthCloudGA__SourceSystemId__c != null]) {
            peerEnums.add(c.HealthCloudGA__SourceSystemId__c);
        } 
        // Get a list of Users from within the list of Contact IDs
        //  Note: this does not check for data integrity of the Contact name matching the User name correctly
        List<User> peerUsers = new List<User>([SELECT Id FROM User WHERE employeeNumber IN :peerENums]);
        if (peerUsers.isEmpty()) {
            return;
        }
        Integer numPeers = peerUsers.size();

        List<EventRelation> samplePeers = new List<EventRelation>();
        // Placeholder in the peerUsers list for the next peer to be inserted
        Integer currentPeerIndex = 0;
        for (Event se : sampleEvents) {
            // Add the affected UserID as an attendee since the calendar entry is owned by the admin
            EventRelation er1 = new EventRelation(EventId=se.Id,RelationId=inputVars[0].userId);
            samplePeers.add(er1);
            // Also add a peer as an attendee
            User thisUser = peerUsers.get(currentPeerIndex);
            Id thisPeerId = thisUser.Id;
            EventRelation er2 = new EventRelation(EventId=se.Id,RelationId=thisPeerId);
            samplePeers.add(er2);
            // Move to the next peer in the list
            if (currentPeerIndex < (numPeers-1)) {
                // Increment our placeholder
                currentPeerIndex++;
            } else {
                // If we've reached the end of the peer list, go back to the beginning
                currentPeerIndex = 0;
            }
        }
        // Insert the peers as EventRelations
        try {
            Database.SaveResult[] peerResult = Database.insert(samplePeers,false);
        } catch(DmlException e) {
            System.debug('The following exception has occurred: ' + e.getMessage());
        }

        // TO DO: Comment out debug
        System.Debug(sampleEvents);
        System.Debug(samplePeers);
//        delete sampleEvents;
    }
}
