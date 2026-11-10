const fs = require('fs');

async function main() {
    const issueData = require('child_process').execSync('curl -s https://api.github.com/repos/simonoppowa/OpenNutriTracker/issues/1596').toString();
    console.log(JSON.parse(issueData).body);
}

main();
