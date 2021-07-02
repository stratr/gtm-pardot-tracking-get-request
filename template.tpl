___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Pardot Tracking - GET Request",
  "brand": {
    "id": "brand_dummy",
    "displayName": ""
  },
  "description": "Experimental version of a custom Pardot tracking code that doesn\u0027t inject the pd.js script. Can be used to for example set the tracking opt-in or to track page views.",
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "accountId",
    "displayName": "Pardot Account Id",
    "simpleValueType": true,
    "help": "Enter the piAId value from the Pardot tracking script.",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ],
    "valueHint": "piAId",
    "alwaysInSummary": true
  },
  {
    "type": "TEXT",
    "name": "campaignId",
    "displayName": "Pardot Campaign Id",
    "simpleValueType": true,
    "help": "Enter the piCId value from the Pardot tracking script. Leave blank if the value in the tracking code is blank.",
    "valueHint": "piCId",
    "alwaysInSummary": true
  },
  {
    "type": "TEXT",
    "name": "piHostname",
    "displayName": "Pardot Tracking Hostname",
    "simpleValueType": true,
    "help": "Enter the piHostname value from the Pardot tracking script.",
    "valueHint": "piHostname",
    "alwaysInSummary": true,
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ]
  },
  {
    "type": "RADIO",
    "name": "trackingOptInEnabled",
    "displayName": "Pardot Tracking Opt-in Enabled?",
    "radioItems": [
      {
        "value": true,
        "displayValue": "True",
        "subParams": [
          {
            "type": "TEXT",
            "name": "piOptIn",
            "displayName": "PI Opt-in",
            "simpleValueType": true,
            "alwaysInSummary": false,
            "help": "Has the visitor given consent? Use a GTM variable: \"true\" / \"false\"",
            "valueValidators": []
          }
        ],
        "help": ""
      },
      {
        "value": false,
        "displayValue": "False"
      }
    ],
    "simpleValueType": true,
    "defaultValue": true,
    "help": "Has tracking opt-in been enabled in Pardot settings?"
  },
  {
    "type": "LABEL",
    "name": "optInInfo1",
    "displayName": "Note when setting Pardot Tracking Opt-in"
  },
  {
    "type": "LABEL",
    "name": "optInInfo2",
    "displayName": "Pardot by default does not support changing an already set consent choice. Firing the tag again with a different value would not change the setting."
  },
  {
    "type": "LABEL",
    "name": "optInInfo3",
    "displayName": "However, Pardot can change a setting in the account that allows for changing the consent setting from the tag. See this link: https://help.salesforce.com/articleView?id\u003d000313156\u0026language\u003den_US\u0026type\u003d1\u0026mode\u003d1"
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

/*
Custom Pardot tracking code template by Fluido.
Created by: Taneli Salonen, taneli.salonen@fluidogroup.com
Updated: 2020-04-26

Known functionality that's missing:
- Can't run JS code upon response like the original tracking code does. The pd.js code runs a script to set the visitor id as a cookie upon response. This is an addition to the server side cookie that the response sets.
- Missing analytics params: pi_points, pi_include_in_activies, read from global variables: piIncludeInActivities & piProfileId
*/

// Required functions
const log = require('logToConsole');
const getType = require('getType');
const makeString = require('makeString');
const makeNumber = require('makeNumber');
const getUrl = require('getUrl');
const getReferrerUrl = require('getReferrerUrl');
const readTitle = require('readTitle');
const encodeUriComponent = require('encodeUriComponent');
const sendPixel = require('sendPixel');
const getCookieValues = require('getCookieValues');
const getQueryParameters = require('getQueryParameters');

function getFirstCookieVal(cookieName) {
  // returns the first value for a cookie in case there are several values for the same name
  // return '' for non existent values
  const cookieVals = getCookieValues(cookieName);
  return cookieVals.length > 0 ? cookieVals[0]: '';
}

// Check that the main inputs are valid
if (data.accountId && (getType(data.accountId) === 'number' || getType(data.accountId) === 'string') && makeNumber(data.accountId) > 0) {
  
  // Basic parameters included in every request
  const accountId = makeString(data.accountId);
  const campaignId = data.campaignId ? 
        makeString(data.campaignId) : getQueryParameters('pi_campaign_id', false) ? 
        getQueryParameters('pi_campaign_id', false): '';
  const hostname = data.piHostname;
  const protocol = getUrl('protocol');
  const referrer = getReferrerUrl() ? getReferrerUrl() : getQueryParameters('referrer', false) ? 
        getQueryParameters('referrer', false): '';
  const url = getUrl() ? getUrl() : '';
  const title = readTitle() ? readTitle() : '';
  
  // Opt-in parameter
  let piOptIn = data.trackingOptInEnabled ? '': null;
  if (data.trackingOptInEnabled && (data.piOptIn === 'true' || data.piOptIn === true)) {
    piOptIn = 'true';
  } else if (data.trackingOptInEnabled && (data.piOptIn === 'false' || data.piOptIn === false)) {
    piOptIn = 'false';
  }
  
  /*
  Visitor parameters (These are included in the requests if they exist. The response sets the values for these.)
  The analytics response sets the id params in a subdomain. There is no way to access those parameters with JS from another subdomain.
  Pd.js should be used to set the parameters on the calling subdomain as well. Although, it's questionable if the parameters are needed in
  the request or not as query parameters because they are transferred anyways through the cookie headers.
  */
  const visitorId = getFirstCookieVal('visitor_id' + accountId);
  const visitorId_sign = getFirstCookieVal('visitor_id' + accountId + '-hash');

  // Tracking endpoint base URL
  const analyticsHostname = (data.piHostname === 'pi.pardot.com' && protocol === 'http') ? 'cdn.pardot.com' : data.piHostname;
  const baseUrl = protocol + '://' + analyticsHostname + '/analytics?';
  
  //log(baseUrl);
  
  /*
  Analytics request parameters
  Every value that is a string is added to the payload.
  Some params, like visitor_id, are always passed, even with an empty string.
  Other parameter, like utm tags are only added when they have a value. If they don't have a value, null should be passed.
  */
  
  // Common parameters, these are always present, even with "" as value
  const commonParams = [
    ['ver', '3'],
    ['visitor_id', visitorId],
    ['visitor_id_sign', visitorId_sign],
    ['pi_opt_in', piOptIn],
    ['campaign_id', campaignId],
    ['account_id', accountId],
    ['title', title],
    ['url', url],
    ['referrer', referrer]
  ];

  // These parameters are just captured from the current page's URL as they are
  const urlParams = [
    'pi_ad_id',
    'creative',
    'matchtype',
    'keyword',
    'network',
    'pi_profile_id',
    'pi_email',
    'pi_list_email',
    'utm_campaign',
    'utm_medium',
    'utm_source',
    'utm_content',
    'gclid',
    'device'
  ].map(function(param) {
    return [param, getQueryParameters(param, false)];
  });
  
  // Special logic params from page URL
  const specialUrlParams = [
    ['utm_term', getQueryParameters('utm_term', false) ? getQueryParameters('utm_term', false) : getQueryParameters('_kk', false)]
  ];
  
  // Get only the params that have a string value and join them into the payload.
  // Encode the values of the parameters
  const concatParams = commonParams.concat(urlParams).concat(specialUrlParams);
  const hitParams = concatParams.filter(function(param) {
    return getType(param[1]) === 'string';
  }).map(function(param) {
    return param[0] + '=' + encodeUriComponent(param[1]);
  }).join('&');
  
  // Construct the final tracking 
  const trackingUrl = baseUrl + hitParams;
  //log(trackingUrl);
  
  sendPixel(trackingUrl, data.gtmOnSuccess(), data.gtmOnFailure());
}

data.gtmOnFailure();


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "get_url",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urlParts",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "queriesAllowed",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "get_referrer",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urlParts",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "queriesAllowed",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_title",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "send_pixel",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedUrls",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "get_cookies",
        "versionId": "1"
      },
      "param": [
        {
          "key": "cookieAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Basic test
  code: |-
    const mockData = {
      accountId: '90244',
      campaignId: null,
      piHostname: 'go.account.com',
      trackingOptInEnabled: true,
      piOptIn: 'true'
    };

    const pageUrl = 'https://www.fluidogroup.com?utm_campaign=test';

    log('testing');

    mock('getUrl', (part) => {
      if (part === 'protocol') {
        return 'https';
      }
      return pageUrl;
    });

    mock('getQueryParameters', (param, retrieveAll) => {
      const url = pageUrl;
      const parts = url.split('?');
      if (parts.length > 1) {
        const query = parts[1];
        const params = query.split('&');
        for (var i = 0; i < params.length; i++) {
          if (params[i].indexOf(param) === 0) {
            log('param: ' + params[i].split('=')[1]);
            return params[i].split('=')[1];
          }
        }
      }
      return null;
    });

    mock('getReferrerUrl', () => {
      return 'https://www.google.com';
    });

    mock('readTitle', () => {
      return 'Page title';
    });

    const variableResult = [];

    mock('sendPixel', (url, onSuccess, onFailure) => {
      const params = url.split('?')[1].split('&');
      params.forEach(param => {
        variableResult.push(param);
      });
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    log(variableResult);

    const expectedResult = [];

    // Verify that the tag finished successfully.
    assertApi('gtmOnSuccess').wasCalled();
setup: const log = require('logToConsole');


___NOTES___

Created on 5.2.2021 klo 12.32.11


