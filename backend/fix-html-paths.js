#!/usr/bin/env node

/**
 * Script to update HTML file paths for API Gateway stage deployment
 * This script updates relative paths in the HTML file to include the API Gateway stage prefix
 */

const fs = require('fs');
const path = require('path');

const DIST_DIR = './dist';
const HTML_FILE = path.join(DIST_DIR, 'index.html');
const STAGE = process.env.API_STAGE || 'prod';

function updateHtmlPaths() {
    if (!fs.existsSync(HTML_FILE)) {
        console.error(`HTML file not found: ${HTML_FILE}`);
        return;
    }

    let htmlContent = fs.readFileSync(HTML_FILE, 'utf8');
    
    // Update relative paths to include stage prefix
    htmlContent = htmlContent.replace(
        /src="\.\/assets\//g,
        `src="/${STAGE}/assets/`
    );
    
    htmlContent = htmlContent.replace(
        /href="\.\/assets\//g,
        `href="/${STAGE}/assets/`
    );
    
    // Also handle absolute paths that don't include stage
    htmlContent = htmlContent.replace(
        /src="\/assets\//g,
        `src="/${STAGE}/assets/`
    );
    
    htmlContent = htmlContent.replace(
        /href="\/assets\//g,
        `href="/${STAGE}/assets/`
    );

    // Handle paths that already have a stage prefix (replace with current stage)
    htmlContent = htmlContent.replace(
        /src="\/[^/]+\/assets\//g,
        `src="/${STAGE}/assets/`
    );
    
    htmlContent = htmlContent.replace(
        /href="\/[^/]+\/assets\//g,
        `href="/${STAGE}/assets/`
    );

    fs.writeFileSync(HTML_FILE, htmlContent);
    console.log(`Updated HTML file with stage prefix: ${STAGE}`);
}

if (require.main === module) {
    updateHtmlPaths();
}

module.exports = { updateHtmlPaths };
