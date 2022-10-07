# Apex Code Analysis
This repo contains SObject and shell scripts used to persist code analysis reports summary in Salesforce
# Disclaimer
Apex Code Analysis is not an official Salesforce product, it has not been officially tested or documented by Salesforce.

## How to follow technical debt ?

You can monitor technical debt on the dashboard **Technical Debt Evolution**

<img alt="Dashboard" src="./screenshots/dashboard.png" />

## How does it works ?

The pmd rules are configured in the file [custom-apex-rules.xml](./custom-apex-rules.xml)

When running pmd command, we add a parameter (*xsltFilename*) to define export format and the template to use:

```sh
$PMD_FOLDER/run.sh pmd --minimum-priority $MINIMUM_PRIORITY -d force-app -R ../custom-apex-rules.xml -f xslt -l apex -property xsltFilename=pmd-nicerhtml.xsl > PMDReport.html
```

Then, the generated html report is parsed to extract the needed data to insert the SObject.

You can re-use this report to copy it into your staticResource folder to be able to see it in Salesforce after deployment.
<img alt="PMD Report" src="./screenshots/pmd-report.png" />

```sh
mv PMDReport.html ./force-app/main/default/staticResources/PMDReport.html
```

## Deploy to Salesforce

# Needed packages

awk
sed
grep
jq


Before deploying this fodler to salesforce, you need to update the [CustomHelpMenuSection](./force-app/main/default/customHelpMenuSections/CustomHelpMenuSection.customHelpMenuSection-meta.xml)

To do so, you can run the following script to update it based on your sfdx (already defined) org default.
<img alt="Help Menu" src="./screenshots/help-menu.png" />

```sh
#TODO script update file based on
```

Checkout the repo and deploy it with sfdx:
```sh
sfdx force:source:deploy -p force-app
```

Use GitHub Salesforce Deploy Tool:

[<img alt="Deploy to Salesforce" src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png" />](https://githubsfdeploy.herokuapp.com/?owner=tprouvot&repo=apex-analysis&ref=main)