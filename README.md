Requirements:

Postfix or other locally run mail server, Ruby, Internet access

Configuration:

Constants are at top of file. Specify your sending email address, recipients, and NOAA fire weather URL (such as the one left in the code). NOAA updates fire weather outlooks twice a day. Where I live they get issued around 0900 and 1600. Run this script via a cronjob after your daily issuing times (providing for a buffer zone in case outlooks are issued late). Sit back and get alerted when extreme fire behavior is expected.
