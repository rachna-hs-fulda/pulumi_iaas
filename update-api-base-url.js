#!/usr/bin/env node

/**
 * Script to update frontend API base URL from "/" to "/prod/"
 * This script updates the API base URL in built frontend assets
 */

const fs = require('fs');
const path = require('path');

const DIST_DIR = './backend/dist/assets';
const STAGE = process.env.API_STAGE || 'prod';

function updateApiBaseUrl() {
    if (!fs.existsSync(DIST_DIR)) {
        console.error(`Assets directory not found: ${DIST_DIR}`);
        return;
    }

    const files = fs.readdirSync(DIST_DIR);
    const jsFiles = files.filter(file => file.endsWith('.js'));

    if (jsFiles.length === 0) {
        console.error('No JavaScript files found in assets directory');
        return;
    }

    let updatedFiles = 0;

    jsFiles.forEach(file => {
        const filePath = path.join(DIST_DIR, file);
        let content = fs.readFileSync(filePath, 'utf8');
        
        // Update API base URL from "api/v1" to "/prod/api/v1" (or whatever stage is specified)
        const oldPattern = /Na="api\/v1"/g;
        const newPattern = `Na="/${STAGE}/api/v1"`;
        
        if (content.match(oldPattern)) {
            content = content.replace(oldPattern, newPattern);
            fs.writeFileSync(filePath, content);
            console.log(`Updated API base URL in ${file}`);
            updatedFiles++;
        }
    });

    if (updatedFiles === 0) {
        console.log('No files needed updating. API base URL may already be correct.');
    } else {
        console.log(`Successfully updated ${updatedFiles} file(s) to use base URL: /${STAGE}/api/v1`);
    }
}

if (require.main === module) {
    updateApiBaseUrl();
}

module.exports = { updateApiBaseUrl };
