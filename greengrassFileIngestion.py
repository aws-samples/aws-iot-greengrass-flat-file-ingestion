# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import sys
import greengrasssdk
import platform
import os
import logging
import csv
import json
import time
from threading import Timer

# When deployed to a Greengrass core, this code will be executed immediately
# as a long-lived lambda function.  The code will enter the infinite while
# loop below.
# If you execute a 'test' on the Lambda Console, this test will fail by
# hitting the execution timeout of three seconds.  This is expected as
# this function never returns a result.


# Setup logging to stdout
logger = logging.getLogger(__name__)
logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

# Create a Greengrass Core SDK client.
client = greengrasssdk.client('iot-data')
volumePath = '/samba/iot'

# Main function
def ingest_files():
    try:
        file_name = volumePath + '/iotdata.csv'

        # Parse csv into JSON and write to IoT Cloud
        with open(file_name, 'rU') as csv_file:
            csv_reader = csv.DictReader(csv_file)
            for rows in csv_reader:
                json_data = json.dumps(rows, indent=4)
                client.publish(topic='iot/data', payload=json_data)
        os.remove(file_name)
    except Exception as e:
        logger.error('Failed to publish message: ' + repr(e))
    
    # Asynchronously schedule this function to be run again in 5 seconds
    Timer(5, ingest_files).start()

# Start executing the function above.
ingest_files()

# This is a dummy handler and will not be invoked
# Instead the code above will be executed in an infinite loop for our example
def function_handler(event, context):
    return