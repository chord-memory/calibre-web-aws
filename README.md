# calibre-web-aws

The calibre-web-aws project serves to deploy a [Calibre-Web](https://github.com/janeczku/calibre-web) docker container fronted by a [Caddy](https://caddyserver.com/docs/) reverse proxy, in addition to a small Flask API for exposing the progress % over HTTPS. [chord-memory.net](https://github.com/chord-memory/chord-memory-net) utilizes the deployed Calibre-Web & API to display progress % for eBooks on Kobo via the Kobo Sync feature.

While the Calibre-Web instance runs in an EC2 instance in AWS, it needs access to a Calibre desktop library which I maintain locally on my Mac. To maintain synchronicity, I sync my local Calibre library to S3 and then from S3 to the EBS storage used by the Calibre-Web EC2 instance when I add new books or Annotations. More details in [Manually Sync Calibre Desktop & Calibre-Web](#manually-sync-calibre-desktop--calibre-web) below.

## Run Locally

If you want to experiment with Calibre-Web locally before deploying to AWS.

<details>
  <summary>See local deployment details:</summary><br>

  Requires docker and docker-compose. For Mac, simply install Docker Desktop from the docker website [here](https://docs.docker.com/desktop/setup/install/mac-install/).

  To test run the official [calibre-web](https://hub.docker.com/r/linuxserver/calibre-web) image on Mac, cd into the `local` directory and run:
  ```
  docker-compose up -d
  ```
  and then view the Calibre-Web UI at http://localhost:8083. Ensure your Calibre desktop books are in `~/calibre-library`, otherwise edit `~/calibre-library` in `local/docker-compose.yml` to the location of your Calibre desktop library on your Mac.

  Login with creds:
  * admin/admin123

  On first launch:
  * Calibre-Web will ask for the location of the Calibre library
  * Enter /books (the path inside the container, not on your Mac)

  Follow [Kobo Sync Setup](#kobo-sync-setup) below to enable Kobo Sync between your local Calibre-Web instance and your Kobo. 
</details>

## Deploy to AWS

### AWS Authentication & Domain

The basic AWS setup steps are:
* Install AWS CLI
* Buy Route53 domain
* Enable the IAM Identity Center
* Generate admin user
* Login with admin user to CLI

<details>
  <summary>See AWS setup details:</summary><br>

  Requires the AWS CLI. Install using [Homebrew](https://brew.sh/):
  ```
  brew update
  brew install awscli
  aws --version
  ```

  Manual AWS Console Steps:
  * Buy Route53 domain
  * Take note of the Hosted Zone ID
  * Enable the IAM Identity Center

  Within IAM Identity Center:
  * Create a Permission set "AdministratorAccess" with the "AdministratorAccess" AWS Managed Policy
  * Create a Group "Administrators"
  * Navigate to "AWS Accounts"
  * Select the account where you will be deploying resources
  * Click "Assign users or groups"
  * Select the "Administrators" group and "AdministratorAccess" permission set to link them
  * Create a user for yourself in the "Administrators" group
  * Create your password by clicking "Accept Invitation" in the received email
  * Sign in to setup MFA device

  Login to AWS in the CLI:
  * Execute `aws configure sso`
  * Enter a session name like `jordan-sso`
  * Enter the portal URL from the IAM invite email or from the IAM Identity Center settings
  * Enter the region where you would like to deploy resources
  * Press enter when prompted for SSO registration scopes
  * Enter the region again
  * Press enter when prompted for CLI default output format
  * Enter a profile name like `jordan-sso`

  Example `aws configure sso` output:
  ```
  jordan@Jordans-MBP calibre-web-aws % aws configure sso
  SSO session name (Recommended): jordan-sso
  SSO start URL [None]: https://d-XXXXXXXXXX.awsapps.com/start
  SSO region [None]: us-east-1
  SSO registration scopes [sso:account:access]:
  Attempting to open your default browser.
  If the browser does not open, open the following URL:

  https://oidc.us-east-1.amazonaws.com/authorize?response_type=code&client_id=vurAE0VZDjczgMoDyWp2knVzLWVhc3QtMQ&redirect_uri=http%3A%2F%2F127.0.0.1%3A50327%2Foauth%2Fcallback&state=dcd74d4b-99a0-4965-b90a-5702e1e1d53e&code_challenge_method=S256&scopes=sso%3Aaccount%3Aaccess&code_challenge=mZjrl_HVMO8N9H_HRRZTv4B2nEMBxJI22bz6DciVyJ8
  The only AWS account available to you is: 123456789012
  Using the account ID 123456789012
  The only role available to you is: AdministratorAccess
  Using the role name "AdministratorAccess"
  Default client Region [None]: us-east-1
  CLI default output format (json if not specified) [None]:
  Profile name [AdministratorAccess-123456789012]: jordan-sso
  To use this profile, specify the profile name using --profile, as shown:

  aws sts get-caller-identity --profile jordan-sso
  jordan@Jordans-MBP calibre-web-aws %
  ```

  Example `~/.aws/config` file:
  ```
  jordan@Jordans-MBP calibre-web-aws % cat ~/.aws/config
  [profile jordan-sso]
  sso_session = jordan-sso
  sso_account_id = 123456789012
  sso_role_name = AdministratorAccess
  region = us-east-1
  [sso-session jordan-sso]
  sso_start_url = https://d-XXXXXXXXXX.awsapps.com/start
  sso_region = us-east-1
  sso_registration_scopes = sso:account:access
  ```

  See your profile name listed here:
  ```
  jordan@Jordans-MBP calibre-web-aws % aws configure list-profiles
  jordan-sso
  ```
</details></br>

AWS CLI authentication commands:
* `aws configure list-profiles` outputs profile name e.g. `jordan-sso`
* `aws sts get-caller-identity --profile jordan-sso` to test if you are authenticated
* `export AWS_PROFILE=jordan-sso` to run commands without `--profile` arg
* `aws sso login --profile jordan-sso` to re-auth when session expires

### Terraform Apply

Requires Terraform. Install using [Homebrew](https://brew.sh/):
```
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform --version
```
Generate a `terraform.tfvars` file in `terraform` with the following variables:
```
domain_name    = "cweb.my-domain.net"
profile        = "jordan-sso"
hosted_zone_id = "ZXXXXXXXXXXXXX"
admin_pass     = "CHANGEME"
admin_email    = "you@example.com"
region         = "us-east-1"
```
While logged into the AWS CLI, deploy resources with the commands:
```
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
```

Now visit your Calibre-Web instance in a browser at the specified domain name.

<details>
  <summary>Troubleshooting notes:</summary><br>
  
  Requires the AWS CLI Session Manager plugin. Install using [Homebrew](https://brew.sh/):
  ```
  brew update
  brew install session-manager-plugin
  session-manager-plugin --version
  ```
  * SSH into the EC2 via `aws ssm start-session --target i-xxxxxxxx`
  * Generated user_data file in the EC2 at `/var/lib/cloud/instances/i-xxxxxxxx/user-data.txt`
  * Logs of the user_data script at `/var/log/cloud-init-output.log`
  * View block device attachments via `lsblk` or `fdisk -l` or `blkid`
</details>

### Calibre-Web Setup

Before you can configure the "Location of Calibre Database", you must follow [Manually Sync Calibre Desktop & Calibre-Web](#manually-sync-calibre-desktop--calibre-web) to make your Calibre Desktop database available to Calibre-Web.

Login with creds:
* admin/admin_pass from `terraform.tfvars`

On first launch:
* Calibre-Web will ask for the location of the Calibre library
* Enter /books (the path inside the container, not on your Mac)

Follow [Kobo Sync Setup](#kobo-sync-setup) below to enable Kobo Sync between your local Calibre-Web instance and your Kobo.

<details>
  <summary>Alternatively, if you would like your AWS Calibre-Web instance to inherit Kobo Sync configuration from your local Calibre-Web, see attached details:</summary><br>

  Requires the AWS CLI Session Manager plugin. Install using [Homebrew](https://brew.sh/):
  ```
  brew update
  brew install session-manager-plugin
  session-manager-plugin --version
  ```
  Your local Calibre-Web configs may be synced to AWS Calibre-Web by running the provided script:
  ```
  # First login to AWS CLI
  aws sso login --profile jordan-sso
  export AWS_PROFILE=jordan-sso
  # Run script (Use EC2 ID)
  ./sync.sh config i-xxxxxxxx
  ```
  Example script output:
  ```
  
  ```
</details>

## Kobo Sync Setup

Once your Calibre-Web instance is running in AWS via the Terraform deployment described above, we can configure Kobo Sync.

<details>
  <summary>If configuring Kobo Sync with a local Calibre-Web instance, see attached details:</summary><br>

  Note:
  * You must visit your Calibre-Web instance at your Macs public IP
  * Run `ipconfig getifaddr en0` or `ipconfig getifaddr en1` to get your Macs public IP
  * Navigate to your local Calibre-Web instance in the browser at `http://<Macs public IP>:8083`
  * And then continue with the steps below

  Note:
  * The sync will only work with your local Calibre-Web if your Mac & Kobo are on the same WiFi network
  * And the AP Isolation setting on the WiFi router is disabled
  * The AP Isolation setting disallows devices on the same network from communicating
  * Try visiting `http://<Macs public IP>:8083` from your phone on the same WiFI network to troubleshoot this
  * If your Calibre-Web UI appears in the browser on your phone then the Kobo Sync should work
</details><br>

<details>
  <summary>If you have already synced your Kobo with a local Calibre-Web and just deployed another Calibre-Web to AWS, see attached details:</summary><br>
  The books synced to your Kobo via local Calibre-Web will be duplicated if you sync your Kobo via AWS Calibre-Web. To prevent this, you can copy your settings from your local Calibre-Web to your AWS Calibre-Web. Use the script provided:

  Requires the AWS CLI Session Manager plugin. Install using [Homebrew](https://brew.sh/):
  ```
  brew update
  brew install session-manager-plugin
  session-manager-plugin --version
  ```
  Execute script:
  ```
  # First login to AWS CLI
  aws sso login --profile jordan-sso
  export AWS_PROFILE=jordan-sso
  # Run script (Use EC2 ID)
  ./sync.sh config i-xxxxxxxx
  ```
  Example script output:
  ```

  ```

  Continue with steps below. Kobo Sync should already be turned on. Essentially just change "Server External Port" from 8083 to 443 and add your new Kobo Sync Token to your Kobo configuration file.
</details>

Steps:
* In Calibre Web > Admin > Edit Basic Configuration > Feature Configuration, check "Enable Kobo Sync"
* Set "Server External Port" to 443 for AWS Calibre-Web (leave at 8083 for local Calibre-Web)
* Under the user profile "admin", click Create/View under Kobo Sync Token
* A popup with a value in the format `api_endpoint=https://example.com/kobo/xxxxxxxxxxxxxxxx` appears
* Connect the Kobo to a computer, and edit the `api_endpoint` config in `.kobo/Kobo/Kobo eReader.conf`
* Unmount the Kobo and click the circular arrows in the upper right corner

Books from Calibre-Web and will be synced to Kobo when "Sync Now" is clicked and the progress % for these books synced to Calibre-Web upon opening/closing the books on the Kobo.

If you care about the progress % being synced from Kobo up to Calibre-Web, you can follow the steps below to ensure the % is being synced.

<details>
  <summary>Reading % sync for Calibre-Web running locally:</summary><br>

  Use `sqlite3 local/config/app.db` to view the progress % changing for books added to the Kobo via Calibre-Web:
  ```
  jordan@Jordans-MBP calibre-web-aws % sqlite3 local/config/app.db
  SQLite version 3.43.2 2023-10-10 13:08:14
  Enter ".help" for usage hints.
  sqlite> .table
  archived_book       flask_dance_oauth   kobo_synced_books   shelf             
  book_read_link      flask_settings      oauthProvider       shelf_archive     
  book_shelf_link     kobo_bookmark       registration        thumbnail         
  bookmark            kobo_reading_state  remote_auth_token   user              
  downloads           kobo_statistics     settings            user_session      
  sqlite> pragma table_info(kobo_bookmark);
  0|id|INTEGER|1||1
  1|kobo_reading_state_id|INTEGER|0||0
  2|last_modified|DATETIME|0||0
  3|location_source|VARCHAR|0||0
  4|location_type|VARCHAR|0||0
  5|location_value|VARCHAR|0||0
  6|progress_percent|FLOAT|0||0
  7|content_source_progress_percent|FLOAT|0||0
  sqlite> select progress_percent from kobo_bookmark where progress_percent is not null;
  9.0
  7.0
  8.0
  11.0
  sqlite>
```
</details>

<details>
  <summary>Reading % sync for Calibre-Web running in AWS:</summary><br>
  You can SSH into the EC2 via `aws ssm start-session --target i-xxxxxxxx` and view the database as referened by the local Calibre-Web steps.
  Or use the provided API endpoints // TODO
</details><br>

Note that any sideloaded books synced from Calibre desktop will be duplicated. See below to safely transition from Calibre desktop to Calibre-Web.

## Transition from Desktop to Web

* Transfer annotations off of Kobo to Calibre desktop via Annotations plugin
* Write down current reading postition for in progress books or sync with KoboUtilities plugin
* Delete all sideloaded books from Kobo // TODO: one by one manually?
* Transfer books from Calibre-Web to Kobo by clicking "Sync Now" on Kobo
* Open in progress books and manually set them to correct reading position or sync with KoboUtilities plugin
* Annotations for previously sideloaded books now live in Calibre Desktop
// TODO: Ensure that Annotations for sideloaded books are not deleted when new Annotations get fetched

## Calibre -> Kobo Workflow

* Upload new ePubs to Calibre desktop
* // TODO: aws s3 sync followed by s3 to ebs sync so Calibre-Web has new data
* Click "Sync Now" on Kobo to send these books to Kobo
* Calibre-Web will convert them to kePub and store the kePub in Calibre desktop directory
* // TODO: now need to pull ebs from s3 back to local so kePubs are there?
* Can still use Calibre desktop to store Annotations
* Cannot use KoboUtilities edit book metadata & cover bc Calibre-Web loaded book will not be recognized by Calibre desktop on Kobo if book metadata & cover are edited in Calibre desktop
* When [this PR](https://github.com/janeczku/calibre-web/pull/3381) is merged then book metadata & cover can be edited in Calibre desktop followed by aws s3/ebs sync and "Sync Now" on Kobo

## Manually Sync Calibre Desktop & Calibre-Web

Requires the AWS CLI Session Manager plugin. Install using [Homebrew](https://brew.sh/):
```
brew update
brew install session-manager-plugin
session-manager-plugin --version
```

When edits are made to Calibre Desktop such as new ePubs added or Annotations synced to it, these changes may be synced to Calibre-Web by running the provided script:
```
# First login to AWS CLI
aws sso login --profile jordan-sso
export AWS_PROFILE=jordan-sso
# Run script (Use EC2 ID)
./sync.sh library i-xxxxxxxx
```
Example script output:
```
jordan@Jordans-MBP calibre-web-aws % ./sync.sh library i-06a6db63a2b478825
Local path [~/calibre-library]: 
Syncing local library to s3 bucket ...
Syncing s3 library to ebs ...
[eee84978-de34-49e5-9c9a-3bd0f0e611ba] Executing command: sudo -u ubuntu aws s3 sync s3://cweb-library /srv/library
[eee84978-de34-49e5-9c9a-3bd0f0e611ba] Waiting for completion
[eee84978-de34-49e5-9c9a-3bd0f0e611ba] Success
jordan@Jordans-MBP calibre-web-aws %
```
