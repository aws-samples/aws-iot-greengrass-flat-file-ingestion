# Ingest and visualize your flat-file IoT data with AWS IoT services

Ingesting and visualizing flat-file data in the same centralized location as your other IoT data can be challenging, especially with older legacy devices. While modern IoT-enabled industrial devices can communicate over standard protocols like MQTT, there are still some legacy devices that generate useful data but are only capable of writing it locally to a flat file. This results in siloed data that is either analyzed in a vacuum without the broader context within which it exists, or it is not made available to business users to be analyzed at all. 

AWS provides a suite of IoT and Edge services that can be used to solve this problem. In this blog, I will walk you through one method of leveraging these services to ingest hard-to-reach data into the AWS cloud and extract business value from it.


# Overview of solution

This solution provides a working example of an edge device running [AWS IoT Greengrass](https://aws.amazon.com/greengrass/?nc=sn&loc=2&dn=2) with a Lambda function that watches a Samba file share for new .csv files (presumably containing device or assembly line data). When it finds a new file, it will transform it to JSON format and write it to [AWS IoT Core](https://aws.amazon.com/iot-core/?nc=sn&loc=2&dn=3). The data is then sent to [AWS IoT Analytics](https://aws.amazon.com/iot-analytics/?nc=sn&loc=2&dn=6) for processing and storage, and [Amazon QuickSight](https://aws.amazon.com/quicksight/) is used to visualize and gain insights from the data.

![Architecture Diagram](../architecture-diagram/greengrass-file-ingestion.png)

Since we don't have an actual on-premises environment to use for this walkthrough, we'll simulate pieces of it:
- In place of the legacy factory equipment, an EC2 instance running Windows Server 2019 will generate data in .csv format and write it to the Samba file share. 
    > We're using a Windows server for this function to demonstrate that the solution is platform agnostic. As long as the flat file is written to a file share, Greengrass can ingest it.
- An EC2 instance running Amazon Linux will act as the edge device and will host AWS IoT Greengrass Core and the Samba share. 
    > In the real world, these could be two separate devices, and the device running Greengrass could be as small as a Raspberry Pi.

# Walkthrough

## Prerequisites
1. [Create a keypair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#prepare-key-pair).
1. [Launch a new CloudFormation stack](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-create-stack.html) using [iot-cfn.yml](iot-cfn.yml). 
    - Parameters:
        - Name the stack `IoTGreengrass`.
        - For `EC2KeyPairName`, use the EC2 keypair you just created for. Leave off the `.pem` extension.
        - For `SecurityAccessCIDR`, use your public IP with a /32 CIDR (i.e. `1.1.1.1/32`). 
            - You can also accept the default of `0.0.0.0/0` if you don't mind SSH and RDP being open to all sources on the EC2 instances in this demo environment.
        - Accept the defaults for the remaining parameters.
    - View the `Resources` tab after stack creation completes. The stack creates the following resources:
        - A VPC with two subnets, two route tables with routes, an internet gateway, and a security group.
        - Two EC2 instances, one running Amazon Linux and the other running Windows Server 2019.
        - An IAM role, policy, and instance profile for the Amazon Linux instance.
        - A Lambda function called `GGSampleFunction`, which we'll update with code to parse our flat-files with AWS IoT Greengrass in a later step.
        - A Greengrass Group, Subscription, and Core.
        - Other supporting objects and custom resource types. 
        > The CloudFormation template is derived from the template provided in [this blog post](https://aws.amazon.com/blogs/iot/automating-aws-iot-greengrass-setup-with-aws-cloudformation/). Check out the post for a detailed description of the template and its various options.
    - View the `Outputs` tab and copy the IPs somewhere handy. You'll need them for multiple provisioning steps below.

## Review the AWS IoT Greengrass resources created by CloudFormation
AWS IoT Greengrass seamlessly extends AWS to edge devices so they can act locally on the data they generate, while still using the cloud for management, analytics, and durable storage. Leveraging a device running Greengrass at the edge, we can interact with flat-file data that was previously difficult to collect, centralize, aggregate, and analyze.

Review the AWS IoT Greengrass resources created on your behalf by CloudFormation:
- Search for `IoT Greengrass` in the Services drop-down menu and select it.
- Click `Manage your Groups`.
- Click `file_ingestion`. 
- Navigate through the `Subscriptions`, `Cores`, and other tabs to review the configurations.
    
    > If you're unfamiliar with AWS IoT Greengrass concepts like Subscriptions and Cores, check out the [AWS IoT Greengrass documentation](https://docs.aws.amazon.com/greengrass/latest/developerguide/what-is-gg.html) for a detailed description.
    

## Setup the Samba file share
We will now setup the Samba file share where we will write our flat-file data. In our demo environment, we're creating the file share on the same server that runs the Greengrass software. In the real world, this file share could be hosted elsewhere as long as the device that runs Greengrass can access it via the network.

1. Follow the instructions in [setup_file_share.md](setup_file_share.md) to setup the Samba file share on the Greengrass EC2 instance.
1. Keep your terminal window open. You'll need it again for a later step.


## Configure Lambda Function for Greengrass
AWS IoT Greengrass provides a Lambda runtime environment for user-defined code that you author in AWS Lambda. Lambda functions that are deployed to an AWS IoT Greengrass Core run in the Core's local Lambda runtime. In this example, we'll update the Lambda function created by CloudFormation with code that watches for new files on the Samba share, parses them, and writes the data to an MQTT topic.

1. Update the Lambda function:
    - Search for `Lambda` in the Services drop-down menu and select it.
    - Select the `file_ingestion_lambda` function.
    - From the `Function code` pane, click `Actions` then `Upload a .zip file`.
    - Upload the provided [zip file](../dist/file_ingestion_greengrass_lambda.zip) containing the Lambda code.
    - Select `Actions` > `Publish new version` > `Publish`.
1. Update the Lambda Alias to point to the new version.
    - Select the `Version: X` drop-down ("X" being the latest version number). 
    - Choose the `Aliases` tab and select `gg_file_ingestion`.
    - Scroll down to `Alias configuration` and select `Edit`. 
    - Choose the newest version number and click `Save`.
        > Do NOT use $LATEST as it is not supported by IoT Greengrass.
1. Associate the Lambda function with AWS IoT Greengrass.
    - Search for `IoT Greengrass` in the Services drop-down menu and select it.
    - Select `Groups` and choose `file_ingestion`.
    - Select `Lambdas` > `Add Lambda`.
    - Click `Use existing Lambda`.
    - Select `file_ingestion_lambda` > `Next`.
    - Select `Alias: gg_file_ingestion` > `Finish`.
    - You should now see your Lambda associated with the Greengrass group.
    - Still on the Lambdas tab, click the ellipsis and choose `Edit configuration`.
    - Change the following Lambda settings then click `Update`:
        - Set `Containerization` to `No container (always)`.
        - Set `Timeout` to 25 seconds.
        - Set `Lambda lifecycle` to `Make this function long-lived and keep it running indefinitely`.

## Finalize Greengrass Settings and Deploy
Before we deploy our Greengrass group to the Greengrass Core device, we need to configure logging and update containerization settings. 
1. Configure Lambda logging and containerization settings.
    - On the Greengrass Group configuration page, choose `Settings`.
    - Under `Local logs configuration`, choose `Edit`.
    - Choose `Add another log type`.
    - Select `User Lambdas` and `Greengrass system`, then click `Update` > `Save`.
    - For `Default Lambda function containerization`, select `No container`. Click `Update default Lambda execution configuration`. If a warning pops up, select `Continue`.
1. Restart the Greengrass daemon:
    - A daemon restart is required after changing containerization settings. Run the following commands on the Greengrass instance to restart the Greengrass daemon:
        ```bash
        cd /greengrass/ggc/core/
        sudo ./greengrassd stop
        sudo ./greengrassd start
        ```
1. Deploy the Greengrass Group to the Core device.
    - Return to the `file_ingestion` Greengrass Group in the console.
    - Select `Actions` > `Deploy`.
    - Select `Automatic detection`.
    - After a few minutes, you should see a `Status` of `Successfully completed`. If the deployment fails, [check the logs](https://docs.aws.amazon.com/greengrass/latest/developerguide/gg-troubleshooting.html#troubleshooting-logs), fix the issues, and deploy again.

## Generate test data  
You will now generate test data that will be ingested by AWS IoT Greengrass, written to IoT Core, and then sent to AWS IoT Analytics and visualized by Amazon QuickSight.

1. Follow the instructions in [generate_test_data.md](generate_test_data.md) to generate the test data.
1. Verify that the data is being written to IoT Core following [these instructions](https://docs.aws.amazon.com/greengrass/latest/developerguide/lambda-check.html) (Use `iot/data` for the MQTT Subscription Topic instead of `hello/world`).

    ![Test MQTT topic](../img/47-test-mqtt-topic.png)

## Setup IoT Analytics
AWS IoT Analytics is a fully-managed service that makes it easy to run and operationalize sophisticated analytics on massive volumes of IoT data without having to worry about the cost and complexity typically required to build an IoT analytics platform. It is the easiest way to run analytics on IoT data and get insights to make better and more accurate decisions for IoT applications and machine learning use cases. Now that our data is in IoT Cloud, it only takes a few clicks to configure AWS IoT Analytics to process, store, and analyze our data.

1. Search for `IoT Analytics` in the Services drop-down menu and select it.
1. Set `Resources prefix` to `file_ingestion` and `Topic` to `iot/data`. Click `Quick Create`.
1. Populate the data set by selecting `Data sets` > `file_ingestion_dataset` >`Actions` > `Run now`. 
    > If you don't get data on the first run, you may need to wait a couple of minutes and run it again.


## Visualize the Data from AWS IoT Analytics in Amazon QuickSight
Amazon QuickSight is a fast, cloud-powered business intelligence service that makes it easy to deliver insights to everyone in your organization. As a fully managed service, QuickSight lets you easily create and publish interactive dashboards that include ML Insights. Dashboards can then be accessed from any device, and embedded into your applications, portals, and websites. We'll use QuickSight to visualize the IoT data in our AWS IoT Analytics data set. 

1. Search for `QuickSight` in the Services drop-down menu and select it.
1. If your account is not signed up for QuickSight yet, follow [these instructions](https://docs.aws.amazon.com/quicksight/latest/user/signing-up.html) to sign up (use Standard Edition for this demo)
1. Build a new report:
    - Click `New analysis` > `New dataset`.
    - Select `AWS IoT Analytics`.
    - Set `Data source name` to `iot-file-ingestion` and select `file_ingestion_dataset`. Click `Create data source`.
    - Click `Visualize`. Wait a moment while your rows are imported into SPICE. 
    - You can now drag and drop data fields onto field wells. See the [QuickSight documentation](https://docs.aws.amazon.com/quicksight/latest/user/creating-a-visual.html) for detailed instructions on creating visuals. 
        - Here is an example of a QuickSight dashboard you can build using the demo data we generated in this walkthrough.

            ![QuickSightDashboard](../img/quicksight-dashboard.png)

# Cleaning up

Be sure to clean up the objects you created to avoid ongoing charges to your account. 
- In Amazon QuickSight, [Cancel your subscription](https://docs.aws.amazon.com/quicksight/latest/user/closing-account.html).
- In AWS IoT Analytics, delete the datastore, channel, pipeline, data set, role, and topic rule you created.
- In CloudFormation, delete the `IoTGreengrass` stack.
- In Amazon CloudWatch, delete the log files associated with this solution.

# Conclusion
Device data that was once out-of-reach is now simple to collect, analyze, and harvest valuable information from thanks to AWS's suite of IoT services. In this walkthrough, we collected and transformed flat-file data at the edge and sent it to IoT Cloud using AWS IoT Greengrass. We then used AWS IoT Analytics to process, store, and analyze that data, and we built an intelligent dashboard to visualize and gain insights from the data using Amazon QuickSight.

For more information on AWS IoT services, check out the overviews, use cases, and case studies on our [product page](https://aws.amazon.com/iot/). If you're new to IoT concepts, I'd highly encourage you to take our free [Internet of Things Foundation Series](https://www.aws.training/Details/Curriculum?id=27289) training.