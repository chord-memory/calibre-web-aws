# calibre-web-aws

The calibre-web-aws project serves to deploy a [Calibre-Web-Automated](https://github.com/crocodilestick/Calibre-Web-Automated) docker container fronted by a [Caddy](https://caddyserver.com/docs/) reverse proxy, in addition to a small Flask API for exposing the progress % over HTTPS. [chord-memory.net](https://github.com/chord-memory/chord-memory-net) utilizes the deployed Calibre-Web-Automated & API to display progress % for eBooks on Kobo via the Kobo Sync feature.

In order for Calibre-Web-Automated to sync annotations & reading progress to [Hardcover](https://hardcover.app/) or to use Hardcover as a metadata provider, generate an account, and generate an API key following [this guide](https://docs.hardcover.app/api/getting-started/#getting-an-api-key). You will use the generated token in steps below.

## Run Locally

If you want to experiment with Calibre-Web-Automated locally before deploying to AWS.

<details>
  <summary>See local deployment details:</summary><br>

  Requires docker and docker-compose. For Mac, simply install Docker Desktop from the docker website [here](https://docs.docker.com/desktop/setup/install/mac-install/).

  Generate a .env file in the `local` directory of the format:
  ```
  LIBRARY_PATH=~/calibre-library
  DOCKER_IMAGE=chord-memory/calibre-web-automated:main
  HARDCOVER_TOKEN="Bearer XXXXXXXXXX"
  ```
  * Provide the correct path to the location of your Calibre desktop library on your Mac for `LIBRARY_PATH`. You can omit the `LIBRARY_PATH` if you do not already have a Calibre desktop libaray.
  * Provide a `DOCKER_IMAGE` e.g. the `chord-memory/calibre-web-automated:main` image which includes the unreleased Hardcover annotations sync feature. You can omit the `DOCKER_IMAGE` to default to the latest official [calibre-web-automated](https://hub.docker.com/r/crocodilestick/calibre-web-automated) image.
  * Provide the Hardover API key mentioned above for `HARDCOVER_TOKEN`. You can omit the `HARDCOVER_TOKEN` if not using Hardcover as a metadata provider. 

  To test run the a Calibre-Web-Automated server on Mac, cd into the `local` directory and run:
  ```
  docker-compose up -d
  ```
  and then view the Calibre-Web-Automated UI at http://localhost:8083. 

  Login with creds:
  * admin/admin123

  // TODO link to how to test the ingest stuff below

  Follow [Kobo Sync Setup](#kobo-sync-setup) below to enable Kobo Sync between your local Calibre-Web-Automated instance and your Kobo. 
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
domain_name     = "cweb.my-domain.net"
profile         = "jordan-sso"
hosted_zone_id  = "ZXXXXXXXXXXXXX"
admin_pass      = "CHANGEME"
admin_email     = "you@example.com"
region          = "us-east-1"
docker_image    = "chord-memory/calibre-web-automated:main"
hardcover_token = "Bearer XXXXXXXXXX"
```
Note that `docker_image` and `hardcover_token` are both optional. You can omit the `hardcover_token` if not using Hardcover as a metadata provider. You can omit the `docker_image` to default to the latest official [calibre-web-automated](https://hub.docker.com/r/crocodilestick/calibre-web-automated) image. In the example above I have provided the `chord-memory/calibre-web-automated:main` image which includes the unreleased Hardcover annotations sync feature.

While logged into the AWS CLI, deploy resources with the commands:
```
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
```
The EC2 instance ID will output from the `terraform apply` command. Keep track of this for future steps.

Now visit your Calibre-Web-Automated instance in a browser at the specified domain name.

Login with creds:
* admin/admin_pass from `terraform.tfvars`

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

## Sync Local Data to AWS

### Sync Calibre Desktop Library to Calibre-Web

If you have a local Calibre desktop library, you must run the sync script to make your Calibre desktop library available to Calibre-Web.

Requires the AWS CLI Session Manager plugin. Install using [Homebrew](https://brew.sh/):
```
brew update
brew install session-manager-plugin
session-manager-plugin --version
```
Also requires jq: `brew install jq`

Execute:
```
# First login to AWS CLI
aws sso login --profile jordan-sso
export AWS_PROFILE=jordan-sso
# Run script (Use EC2 ID)
./sync.sh library i-xxxxxxxx
```

Your books should now be visible in the Calibe-Web-Automated UI in AWS.

### Sync Local Calibre-Web Config to Calibre-Web in AWS

If you have already synced your Kobo with a local Calibre-Web and just deployed another Calibre-Web to AWS, the books synced to your Kobo via local Calibre-Web will be duplicated if you sync your Kobo via AWS Calibre-Web.

<details>
  <summary>See attached details to resolve:</summary><br>
  To prevent book duplication, you can copy your config from your local Calibre-Web to your AWS Calibre-Web. Use the script provided:<br><br>

  Requires the AWS CLI Session Manager plugin. Install using [Homebrew](https://brew.sh/):
  ```
  brew update
  brew install session-manager-plugin
  session-manager-plugin --version
  ```
  Also requires jq: `brew install jq`

  Execute script:
  ```
  # First login to AWS CLI
  aws sso login --profile jordan-sso
  export AWS_PROFILE=jordan-sso
  # Run script (Use EC2 ID)
  ./sync.sh config i-xxxxxxxx
  ```
  Continue with steps below for Kobo Sync Setup. Some steps may be skipped. For example, Kobo Sync should already be turned on, because your configurations were copied from local Calibre-Web to AWS Calibre-Web. Essentially you will just change "Server External Port" from 8083 to 80 and add your new Kobo Sync Token to your Kobo configuration file.
</details><br>

^^^ In progress. For CWA need to sync cwa.db and processed_books as well potentially. Maybe better to just delete all books on eReader before final sync with AWS Calibre-Web. But these notes could be useful for someone migrating from bare metal to AWS.

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

Steps:
* In Calibre Web > Admin > Edit Basic Configuration > Feature Configuration, check "Enable Kobo Sync"
* Set "Server External Port" to 80 for AWS Calibre-Web (leave at 8083 for local Calibre-Web)
* Under the user profile "admin", click Create/View under Kobo Sync Token
* A popup with a value in the format `api_endpoint=http://example.com/kobo/xxxxxxxxxxxxxxxx` appears
* Connect the Kobo to a computer, and edit the `api_endpoint` config in `.kobo/Kobo/Kobo eReader.conf`
* Unmount the Kobo and click the circular arrows in the upper right corner

Books from Calibre-Web-Automated and will be synced to Kobo when "Sync Now" is clicked and the progress % for these books synced to Calibre-Web-Automated upon opening/closing the books on the Kobo.

If you care about the progress % and annotations being synced from Kobo up to Calibre-Web-Automated, you can follow the steps below to ensure the % is being synced.

<details>
  <summary>Reading % sync for Calibre-Web-Automated running locally:</summary><br>

  Use `sqlite3 local/config/app.db` to view the progress % changing for books added to the Kobo via Calibre-Web-Automated:
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

  You can SSH into the EC2 via `aws ssm start-session --target i-xxxxxxxx` and view the database as referened by the local Calibre-Web steps. Open a sqlite shell on your EC2 with `sqlite3 /srv/config/app.db`. Alternatively you can use the provided REST API endpoint:
  ```
  TODO
  ```
</details><br>

<details>
  <summary>Reading % plus Annotations sync for Calibre-Web integrated with Hardcover:</summary><br>

  TODO
</details>

Note that `SideloadedMode=True` from the `.kobo/Kobo/Kobo eReader.conf` file will automatically be edited to `False` upon syncing.
<details>
  <summary>See details below on maintaining SideloadedMode style UI while syncing with Calibre-Web:</summary><br>

  TODO
</details><br>

**Also note that any sideloaded books synced from Calibre desktop will be duplicated**. See below to safely transition from Calibre desktop to Calibre-Web.

## Transition from Desktop to Web

* Transfer annotations off of Kobo to Calibre desktop via Annotations plugin
* Create new Backup Annotations column with `annotations_backup` lookup name
* Backup annotations by selecting all books with Annotations and clicking Edit Metadata in Bulk
  * Search mode: Regular expression
  * Search Field: `#mm_annotations`
  * Search for: `(.|\n)*`
  * Replace with: `\g<0>`
  * Destination Field: `#annotations_backup`
  * Can test with Test text field then Apply
* Write down current reading postition for in progress books or sync bookmark with KoboUtilities plugin
* Note: cannot sync bookmark with KoboUtilies plugin if you have duplicated books via Calibre-Web
* Delete all books from Kobo by navigating to Settings > 
* Transfer books from Calibre-Web to Kobo by clicking "Sync Now" on Kobo
* Open in progress books and manually set them to correct reading position or sync with KoboUtilities plugin
* Annotations for previously sideloaded books now live in Calibre Desktop
// TODO: Ensure that Annotations for sideloaded books are not deleted when new Annotations get fetched

^^^ In progress. We will not need to backup annotations if annotations go to Hardcover now. Reading % sync via KoboUtilities was not working perhaps because books were duplicated. So maybe do this before Syncing. Can test this by deleting all books and restarting. After annotations are backed up ofc. Any way to get Calibe desktop annotations into Hardcover? Prob not. These will be still viewable in Calibe-Web-Automated and Calibre desktop. And annotations could still be synced to Calibre-Desktop if book is added to that library too & metadata not edited between library & ePub

## Calibre -> Kobo Workflow

* Upload new ePubs to Calibre desktop
* // TODO: aws s3 sync followed by s3 to ebs sync so Calibre-Web has new data
* Click "Sync Now" on Kobo to send these books to Kobo
* Calibre-Web will convert them to kePub and store the kePub in Calibre desktop directory
* // TODO: now need to pull ebs from s3 back to local so kePubs are there?
* Can still use Calibre desktop to store Annotations
* Cannot use KoboUtilities edit book metadata & cover bc Calibre-Web loaded book will not be recognized by Calibre desktop on Kobo if book metadata & cover are edited in Calibre desktop
* When [this PR](https://github.com/janeczku/calibre-web/pull/3381) is merged then book metadata & cover can be edited in Calibre desktop followed by aws s3/ebs sync and "Sync Now" on Kobo

^^^ In progress. Annotations should hopefully be in Hardcover now so Calibre Desktop will not be used. Books downloaded from downloader (TODO) or ./sync.sh ingest (TODO)

## Build CWA Image

These are personal notes to remind myself how to publish calibre-web-automated images under my GitHub profile to test new features.

<details>
  <summary>See GHCR publishing steps:</summary><br>

  If GHCR PAT has expired:
  * Generate GitHub Personal Access Token with write/read packages permissions
  * GitHub > Settings > Developer Settings > Personal Access Tokens > Generate New Token (Classic)
  * Token name: `ghcr-docker`, Select `write:packages` (`read:packages` and `repo` auto-selects)
  * Copy token into `GHCR_PAT="<token>"` in .env in calibre-web-aws directory

  Execute:
  ```
  ./build.sh
  ```

  Note that I manually edited the package to be public in the GitHub UI.
</details>
