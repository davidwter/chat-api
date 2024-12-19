import asyncio
import json
import csv
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

from playwright.async_api import async_playwright, Page, TimeoutError as PlaywrightTimeout
from rich.console import Console
from rich.progress import (
    Progress,
    SpinnerColumn,
    TextColumn,
    BarColumn,
    TaskID,
    TimeElapsedColumn,
    TimeRemainingColumn,
    MofNCompleteColumn
)
from rich.panel import Panel
from rich.live import Live
from rich.table import Table
from rich import print as rprint

# Configuration
BASE_URL = "https://www.workato.com/integrations"
RATE_LIMIT_DELAY = 2  # seconds between requests
STATE_FILE = "scraper_state.json"
OUTPUT_DIR = "workato_data"
TIMEOUT = 30000  # 30 seconds

console = Console()

class WorkatoScraper:
    def __init__(self):
        self.processed_connectors: Dict[str, bool] = {}
        self.data: List[Dict] = []
        self.stats = {
            "total_connectors": 0,
            "processed": 0,
            "successful": 0,
            "failed": 0,
            "skipped": 0,
            "triggers_found": 0,
            "actions_found": 0,
        }
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        
        # Initialize by loading existing data and state
        self._load_existing_data()
        self.processed_connectors = self._load_state()

    def _load_existing_data(self):
        """Load existing data from latest files if they exist."""
        latest_json = Path(OUTPUT_DIR) / "workato_connectors_latest.json"
        if latest_json.exists():
            try:
                with open(latest_json, 'r') as f:
                    self.data = json.load(f)
                console.print(f"[green]Loaded {len(self.data)} existing connectors from {latest_json}[/green]")
                if self.data:
                    last_connector = self.data[-1]["name"]
                    console.print(f"[yellow]Will resume after: {last_connector}[/yellow]")
            except Exception as e:
                console.print(f"[red]Error loading existing data: {str(e)}[/red]")

    def _load_state(self) -> Dict[str, bool]:
        """Load the previous state if it exists."""
        state = {}
        if os.path.exists(STATE_FILE):
            try:
                with open(STATE_FILE, 'r') as f:
                    state = json.load(f)
                # Update processed count from existing state
                self.stats["processed"] = len([v for v in state.values() if v])
                self.stats["successful"] = len(self.data)
                console.print(f"[green]Loaded state for {len(state)} connectors[/green]")
            except Exception as e:
                console.print(f"[red]Error loading state: {str(e)}[/red]")
        return state

    def _save_state(self):
        """Save the current progress."""
        with open(STATE_FILE, 'w') as f:
            json.dump(self.processed_connectors, f)
        
        # Display current statistics
        table = Table(show_header=True, header_style="bold magenta")
        table.add_column("Metric")
        table.add_column("Value", justify="right")
        
        table.add_row("Connectors Processed", str(self.stats["processed"]))
        table.add_row("Successful", f"[green]{self.stats['successful']}[/green]")
        table.add_row("Failed", f"[red]{self.stats['failed']}[/red]")
        table.add_row("Skipped", f"[yellow]{self.stats['skipped']}[/yellow]")
        table.add_row("Triggers Found", str(self.stats["triggers_found"]))
        table.add_row("Actions Found", str(self.stats["actions_found"]))
        
        console.print("\nCurrent Statistics:", style="bold blue")
        console.print(table)

    def _save_data(self, final=False):
        """Save the scraped data to both JSON and CSV."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S") if final else "latest"
        
        # Save JSON
        json_path = Path(OUTPUT_DIR) / f"workato_connectors_{timestamp}.json"
        with open(json_path, 'w') as f:
            json.dump(self.data, f, indent=2)

        # Save CSV (flattened structure)
        csv_path = Path(OUTPUT_DIR) / f"workato_connectors_{timestamp}.csv"
        
        try:
            csv_data = []
            # Prepare flattened data for CSV
            for connector in self.data:
                # Add triggers
                if connector.get('triggers'):
                    for trigger in connector['triggers']:
                        row = {
                            'connector_name': connector['name'],
                            'connector_url': connector['url'],
                            'type': 'trigger',
                            'name': trigger['name'],
                            'description': trigger.get('description', ''),
                            'attributes': json.dumps(trigger.get('attributes', {}))
                        }
                        csv_data.append(row)
                
                # Add actions
                if connector.get('actions'):
                    for action in connector['actions']:
                        row = {
                            'connector_name': connector['name'],
                            'connector_url': connector['url'],
                            'type': 'action',
                            'name': action['name'],
                            'description': action.get('description', ''),
                            'attributes': json.dumps(action.get('attributes', {}))
                        }
                        csv_data.append(row)

            if csv_data:
                # Write CSV file
                fieldnames = ['connector_name', 'connector_url', 'type', 'name', 'description', 'attributes']
                with open(csv_path, 'w', newline='') as f:
                    writer = csv.DictWriter(f, fieldnames=fieldnames)
                    writer.writeheader()
                    writer.writerows(csv_data)

                if final:
                    console.print(Panel(
                        f"✓ Data saved successfully!\n\nJSON: {json_path}\nCSV: {csv_path}",
                        title="Export Complete",
                        border_style="green"
                    ))
            else:
                console.print("[yellow]Warning: No data to write to CSV[/yellow]")
                
        except Exception as e:
            console.print(f"[red]Error saving CSV: {str(e)}[/red]")


    async def _get_connector_details(self, page: Page, url: str, name: str) -> Optional[Dict]:
        """Extract triggers and actions from a connector page."""
        try:
            console.print(f"📥 Processing [cyan]{name}[/cyan] ({url})")
            await page.goto(url)
            await page.wait_for_load_state('networkidle')

            # Find trigger and action sections
            triggers = []
            actions = []
            
            # Get triggers (first column with triggers title)
            try:
                trigger_section = await page.query_selector('section.apps-page__builder-column .apps-page__builder-triggers:has(.apps-page__builder-title_triggers)')
                if trigger_section:
                    trigger_items = await trigger_section.query_selector_all(".apps-page__builder-item:not(.apps-page__builder-item_show-more)")
                    if trigger_items:
                        console.print(f"  Found [green]{len(trigger_items)}[/green] triggers")
                        for elem in trigger_items:
                            try:
                                # Get the main text (title) from the legend
                                legend = await elem.query_selector(".apps-page__builder-legend")
                                if legend:
                                    name = (await legend.evaluate('el => el.childNodes[0].textContent.trim()')).strip()
                                    
                                    # Get the info text
                                    info = await elem.query_selector(".apps-page__builder-info")
                                    description = await info.text_content() if info else ""
                                    
                                    # Check for badges
                                    badges = await elem.query_selector(".operation-badge")
                                    badge_text = await badges.text_content() if badges else ""
                                    
                                    triggers.append({
                                        'name': name,
                                        'description': description,
                                        'attributes': {
                                            'badge': badge_text
                                        } if badge_text else {}
                                    })
                                    self.stats["triggers_found"] += 1
                            except Exception as e:
                                console.print(f"[yellow]Warning: Could not process trigger: {str(e)}[/yellow]")
                else:
                    console.print("[yellow]No trigger section found[/yellow]")
            except Exception as e:
                console.print(f"[red]Error processing triggers section: {str(e)}[/red]")
            
            # Get actions (second column)
            try:
                action_section = await page.query_selector('section.apps-page__builder-column:nth-child(2) .apps-page__builder-triggers')
                if action_section:
                    action_items = await action_section.query_selector_all(".apps-page__builder-item:not(.apps-page__builder-item_show-more)")
                    if action_items:
                        console.print(f"  Found [green]{len(action_items)}[/green] actions")
                        for elem in action_items:
                            try:
                                # Get the main text (title) from the legend
                                legend = await elem.query_selector(".apps-page__builder-legend")
                                if legend:
                                    name = (await legend.evaluate('el => el.childNodes[0].textContent.trim()')).strip()
                                    
                                    # Get the info text
                                    info = await elem.query_selector(".apps-page__builder-info")
                                    description = await info.text_content() if info else ""
                                    
                                    # Check for badges
                                    badges = await elem.query_selector(".operation-badge")
                                    badge_text = await badges.text_content() if badges else ""
                                    
                                    actions.append({
                                        'name': name,
                                        'description': description,
                                        'attributes': {
                                            'badge': badge_text
                                        } if badge_text else {}
                                    })
                                    self.stats["actions_found"] += 1
                            except Exception as e:
                                console.print(f"[yellow]Warning: Could not process action: {str(e)}[/yellow]")
                else:
                    console.print("[yellow]No action section found[/yellow]")
            except Exception as e:
                console.print(f"[red]Error processing actions section: {str(e)}[/red]")

            return {
                'triggers': triggers,
                'actions': actions
            }

        except PlaywrightTimeout:
            console.print(f"[yellow]⚠️ Timeout while processing {url}[/yellow]")
            return None
        except Exception as e:
            console.print(f"[red]❌ Error processing {url}: {str(e)}[/red]")
            return None

    async def _get_element_text(self, element, selector: str) -> str:
        """Safely extract text content from an element."""
        try:
            text_elem = await element.query_selector(selector)
            if text_elem:
                return (await text_elem.text_content()).strip()
        except Exception:
            pass
        return ""

    async def _get_element_attributes(self, element) -> Dict:
        """Extract any additional attributes from the element."""
        attributes = {}
        try:
            for attr in ['data-type', 'data-category', 'data-requirements']:
                value = await element.get_attribute(attr)
                if value:
                    attributes[attr] = value
        except Exception:
            pass
        return attributes

    async def scrape(self):
        """Main scraping function."""
        console.print(Panel("Starting Workato Connector Scraper", style="bold blue"))
        
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            page = await browser.new_page()
            
            try:
                with Progress(
                    SpinnerColumn(),
                    TextColumn("[progress.description]{task.description}"),
                    BarColumn(),
                    MofNCompleteColumn(),
                    TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
                    TimeElapsedColumn(),
                    TimeRemainingColumn(),
                ) as progress:
                    
                    # Get connector list
                    console.print("🔍 Fetching connector list...")
                    await page.goto(BASE_URL)
                    await page.wait_for_load_state('networkidle')
                    
                    connector_elements = await page.query_selector_all("span.adapter-list__item-name")
                    connector_names = []
                    for elem in connector_elements:
                        name = await elem.text_content()
                        if name:
                            connector_names.append(name.strip())
                    
                    self.stats["total_connectors"] = len(connector_names)
                    console.print(f"📋 Found [green]{len(connector_names)}[/green] connectors")
                    
                    # Create progress bar
                    task_id = progress.add_task(
                        "[cyan]Scraping connectors...", 
                        total=len(connector_names)
                    )
                    
                    # Process each connector
                    for name in connector_names:
                        # Skip if already in our data
                        if any(item["name"] == name for item in self.data):
                            self.stats["skipped"] += 1
                            progress.advance(task_id)
                            continue
                        
                        self.stats["processed"] += 1
                        
                        # Construct connector URL
                        url = f"{BASE_URL}/{name.lower().replace(' ', '-')}"
                        
                        # Get connector details
                        details = await self._get_connector_details(page, url, name)
                        if details:
                            self.stats["successful"] += 1
                            connector_data = {
                                'name': name,
                                'url': url,
                                **details
                            }
                            self.data.append(connector_data)
                            # Save data after each successful connector
                            self._save_data(final=False)
                        else:
                            self.stats["failed"] += 1
                            
                        # Update state
                        self.processed_connectors[name] = True
                        self._save_state()
                        
                        # Rate limiting
                        await asyncio.sleep(RATE_LIMIT_DELAY)
                        progress.advance(task_id)
                    
                    # Save final results with timestamp
                    self._save_data(final=True)
                    
            finally:
                await browser.close()

if __name__ == "__main__":
    scraper = WorkatoScraper()
    asyncio.run(scraper.scrape())
