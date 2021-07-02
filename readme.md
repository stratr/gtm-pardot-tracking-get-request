# Pardot Tracking - GET Request

This Google Tag Manager template makes a GET request to the Pardot analytics endpoint when loaded. The parameters for the GET request are collected similarly as how they are collected by the original pd.js script. 

The main need for this template and a GET request instead of the original script is for the purposes of aligning Pardot with the website's cookie consent and an external consent management solution. You can see more details here: https://help.salesforce.com/articleView?id=000313156&language=en_US&type=1&mode=1

Another, more experimental, use case would be to entirely replace the pd.js script which doesn't really allow any kind of configuration and might not be the most performant option to set up the tracking.

Usage:
1. Copy the piAId, piCid (could be empty), and piHostname fields from the Pardot generated script to the template variable.
2. Select if Pardot Tracking Opt-in is being used
3. Set the desired opt-in setting: true or false to the PI Opt-in field