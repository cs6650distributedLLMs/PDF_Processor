#!/usr/bin/env python3
"""
Script to update template URLs for API Gateway deployment.
This modifies the HTML templates to use the correct API Gateway URLs.
"""

import os
import re
import argparse

def update_template_urls(template_dir, api_url, static_url):
    """
    Update form action URLs and static resource URLs in HTML templates
    
    Args:
        template_dir (str): Directory containing templates
        api_url (str): API Gateway URL (without trailing slash)
        static_url (str): Static content URL (without trailing slash)
    
    Returns:
        int: Number of modified files
    """
    count = 0
    
    # Process all HTML files in the templates directory
    for root, dirs, files in os.walk(template_dir):
        for file in files:
            if file.endswith('.html'):
                file_path = os.path.join(root, file)
                
                # Read the file
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                modified = False
                
                # Replace form actions
                # From: action="/upload"
                # To: action="https://api.example.com/upload"
                new_content = re.sub(
                    r'action=["\']\/([^\/"][^"\']*)["\']',
                    f'action="{api_url}/\\1"',
                    content
                )
                
                if new_content != content:
                    modified = True
                    content = new_content
                
                # Replace static URLs
                # From: src="/static/
                # To: src="https://static.example.com/static/
                new_content = re.sub(
                    r'(src|href)=["\']\/static\/([^"\']*)["\']',
                    f'\\1="{static_url}/static/\\2"',
                    content
                )
                
                if new_content != content:
                    modified = True
                    content = new_content
                
                # Replace API URLs
                # From: fetch('/api/
                # To: fetch('https://api.example.com/api/
                new_content = re.sub(
                    r'(fetch\(["\'])\/api\/([^"\']*)',
                    f'\\1{api_url}/api/\\2',
                    content
                )
                
                if new_content != content:
                    modified = True
                    content = new_content
                
                # Write the file if modified
                if modified:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Updated {file_path}")
                    count += 1
    
    return count

def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='Update template URLs for API Gateway deployment')
    parser.add_argument('--api-url', required=True, help='API Gateway URL (without trailing slash)')
    parser.add_argument('--static-url', required=True, help='Static content URL (without trailing slash)')
    parser.add_argument('--template-dir', default='templates', help='Directory containing templates')
    
    args = parser.parse_args()
    
    # Validate URLs
    for url in [args.api_url, args.static_url]:
        if url.endswith('/'):
            print(f"Warning: URL {url} should not have a trailing slash")
            url = url.rstrip('/')
    
    # Check if the templates directory exists
    if not os.path.isdir(args.template_dir):
        print(f"Error: Template directory '{args.template_dir}' not found")
        return
    
    # Update templates
    count = update_template_urls(args.template_dir, args.api_url, args.static_url)
    print(f"Updated {count} template files")

if __name__ == "__main__":
    main()