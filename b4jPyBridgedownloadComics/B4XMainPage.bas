B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.85
@EndOfDesignText@

#CustomBuildAction: after packager, %WINDIR%\System32\robocopy.exe, Python temp\build\bin\python /E /XD __pycache__ Doc pip setuptools tests

'Export as zip: ide://run?File=%B4X%\Zipper.jar&Args=Project.zip
'Create a local Python runtime:   ide://run?File=%WINDIR%\System32\Robocopy.exe&args=%B4X%\libraries\Python&args=Python&args=/E
'Open local Python shell: ide://run?File=%PROJECT%\Objects\Python\WinPython+Command+Prompt.exe
'Open global Python shell - make sure to set the path under Tools - Configure Paths. Do not update the internal package.
'ide://run?File=%B4J_PYTHON%\..\WinPython+Command+Prompt.exe

'required libraries: requests , beautifulsoup4
Sub Class_Globals
	Private Root As B4XView
	Private xui As XUI
	Public Py As PyBridge
	Private Button1 As Button
	Private ImageView1 As ImageView
	Private DatePicker1 As DatePicker
	Private TextField1 As TextField
	Private ComboBox1 As ComboBox
	Private Label1 As Label
End Sub

Public Sub Initialize
	
End Sub

'This event will be called once, before the page becomes visible.
Private Sub B4XPage_Created (Root1 As B4XView)
	Root = Root1
	Root.LoadLayout("MainPage")
	Py.Initialize(Me, "Py")
	Dim opt As PyOptions = Py.CreateOptions("Python/python/python.exe")
	Py.Start(opt)

	Wait For Py_Connected (Success As Boolean)
			If Success = False Then
		LogError("Failed to start Python process.")
		Return
	End If
	InitializeComicSelector
	GetComicList
	PrintPythonVersion

End Sub

Private Sub B4XPage_Background
	Py.KillProcess
End Sub

Private Sub Py_Disconnected
	Log("PyBridge disconnected")
End Sub

Private Sub Button1_Click
	Dim comicName As String=TextField1.Text.Trim
	Dim dateVal As String=DateTime.Date(DatePicker1.DateTicks)
	dateVal=GetFormattedDateFromPicker
	Py.Print(dateVal)
	dateVal.Replace("\","-")
	Py.Print(dateVal)
	Wait For (Dwonload_comics(comicName, dateVal)) Complete (result As Object)
	Py.Print(result)
	result=result.As(String).Replace("~","-")
	Dim parser As JSONParser
	parser.Initialize(result)
	Dim jRoot As Map = parser.NextObject
	Dim Success As String = jRoot.Get("success")
	If Success="True" Then	
		Dim date As String = jRoot.Get("date")
		Dim filepath As String = jRoot.Get("filepath")
		Dim title As String = jRoot.Get("title")
		Dim url As String = jRoot.Get("url")
		Log(filepath.LastIndexOf2("/",0))
		Dim img As Image
		Dim fName As String=File.GetName(filepath)
		
		Try
			img.Initialize(File.DirApp & "\comics", fName)
			ImageView1.SetImage(img)
			Label1.Text=title
		Catch
			xui.MsgboxAsync("Not found","Error")	
		End Try
	Else
		xui.MsgboxAsync("Not found","Error")
	End If	
End Sub
'formt date
Sub GetFormattedDateFromPicker As String
	Dim ticks As Long = DatePicker1.DateTicks
	Dim year As Int = DateTime.GetYear(ticks)
	Dim month As Int = DateTime.GetMonth(ticks)
	Dim day As Int = DateTime.GetDayOfMonth(ticks)
    
	Return year & "/" & NumberFormat2(month, 1, 0, 0, False) & "/" & NumberFormat2(day, 1, 0, 0, False)
End Sub
'setup combobox
Sub GetComicList As List
	Dim comics As List
	comics.Initialize
    
	' Popular comics that usually work
	comics.Add("garfield")
	comics.Add("peanuts")
	comics.Add("calvinandhobbes")
	
	
	Return comics
End Sub

' Create a ComboBox for comic selection
Sub InitializeComicSelector
	Dim comics As List = GetComicList
	ComboBox1.Items.AddAll(comics)
	ComboBox1.SelectedIndex = 0
End Sub

Private Sub ComboBox1_SelectedIndexChanged(Index As Int, Value As Object)
	Dim comicName As String=Value.As(String).Trim
	Dim dateVal As String=DateTime.Date(DatePicker1.DateTicks)
	dateVal=GetFormattedDateFromPicker
	Py.Print(dateVal)
	
	Py.Print(dateVal)
	Wait For (Dwonload_comics(comicName, dateVal)) Complete (result As Object)
	Py.Print(result)
	
	result=result.As(String).Replace("~","-")
	Dim parser As JSONParser
	parser.Initialize(result)
	Dim jRoot As Map = parser.NextObject
	Dim date As String = jRoot.Get("date")
	Dim filepath As String = jRoot.Get("filepath")
	'org.json.JSONException: Unterminated object at character 26 of {success=true, filepath=C:\Users\dell\DOCUME-1\b4j\B4J_PY-2\B4J\Objects\comics\calvinandhobbes_2025-11-12.png, title=Calvin and Hobbes by Bill Watterson for November 12, 2025 | GoComics, date=2025/11/12, url=https://www.gocomics.com/calvinandhobbes/2025/11/12}
	Dim Success As String = jRoot.Get("success")
	Dim title As String = jRoot.Get("title")
	Dim url As String = jRoot.Get("url")
	Log($"${date} ${filepath} ${title} ${url} ${Success}"$)
	Log(filepath.LastIndexOf2("/",0))
	Dim img As Image
	Dim fName As String=File.GetName(filepath)
	Log(File.GetName(filepath))
	img.Initialize(File.DirApp & "\comics", fName)
	ImageView1.SetImage(img)
	Label1.Text=title
End Sub
Sub Dwonload_comics(comicName As String, dateValue As String) As ResumableSub
	Dim code As String=$"
#!/usr/bin/env python3
import sys
import json
import os
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin
from datetime import datetime

def download_comic(comic_name, date=None, output_dir="./comics"):
    try:
        print(f"Debug: Starting MANUAL download for '{comic_name}', date: {date}", file=sys.stderr)
        
        # Create output directory
        os.makedirs(output_dir, exist_ok=True)
        
        # Build the URL - GoComics uses YYYY/MM/DD format in URL
        if date and date != "None" and date != "null":
            # Convert from any format to YYYY/MM/DD for URL
            if '-' in date:
                date_parts = date.split('-')
                url_date = f"{date_parts[0]}/{date_parts[1]}/{date_parts[2]}"
            elif '/' in date:
                url_date = date
            else:
                return {"success": False, "error": f"Invalid date format: {date}. Use YYYY-MM-DD or YYYY/MM/DD"}
            
            url = f"https://www.gocomics.com/{comic_name}/{url_date}"
            print(f"Debug: Using specific date URL: {url}", file=sys.stderr)
        else:
            url = f"https://www.gocomics.com/{comic_name}"
            print(f"Debug: Using today's comic URL: {url}", file=sys.stderr)
        
        # Fetch the page
        headers = {
	'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        }
        
        print(f"Debug: Making request to: {url}", file=sys.stderr)
        response = requests.get(url, headers=headers, timeout=30)
        
        if response.status_code == 404:
            return {"success": False, "error": f"Comic not found (404). Check if '{comic_name}' exists and the date is valid."}
        elif response.status_code != 200:
            return {"success": False, "error": f"HTTP Error {response.status_code}: {response.reason}"}
        
        print(f"Debug: Page loaded successfully, parsing HTML...", file=sys.stderr)
        
        # Parse the HTML
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Debug: Save HTML for inspection if needed
        with open("debug_page.html", "w", encoding="utf-8") as f:
            f.write(soup.prettify())
        
        # Find the comic image - try multiple strategies
        comic_img = None
        
        print(f"Debug: Looking for comic image...", file=sys.stderr)
        
        # Strategy 1: Look for specific classes used by GoComics
        selectors = [
	'picture.item-comic-image img',
	'.item-comic-image img',
	'img.item-comic-image',
	'.comic__image img',
	'[data-image*="gocomics.com"]',
	'img[src*="assets.amuniversal.com"]',
	'img[data-src*="assets.amuniversal.com"]',
	'img[src*="gocomics.com"]',
	'img[data-src*="gocomics.com"]'
        ]
        
        for selector in selectors:
            elements = soup.select(selector)
            if elements:
                comic_img = elements[0]
                print(f"Debug: Found image with selector: {selector}", file=sys.stderr)
                break
        
        # Strategy 2: Look for lazy-loaded images
        if not comic_img:
            print(f"Debug: Trying lazy-loaded images...", file=sys.stderr)
            lazy_images = soup.find_all('img', {'data-src': True})
            for img in lazy_images:
                if 'gocomics.com' in str(img.get('data-src', '')) or 'amuniversal' in str(img.get('data-src', '')):
                    comic_img = img
                    print(f"Debug: Found lazy-loaded image", file=sys.stderr)
                    break
        
        # Strategy 3: Look for any image that might be the comic
        if not comic_img:
            print(f"Debug: Scanning all images...", file=sys.stderr)
            all_images = soup.find_all('img')
            for img in all_images:
                src = img.get('src', '') or img.get('data-src', '')
                if 'gocomics.com' in src or 'amuniversal' in src:
                    comic_img = img
                    print(f"Debug: Found potential comic image in all images", file=sys.stderr)
                    break
        
        if not comic_img:
            return {"success": False, "error": "Could not find comic image on the page. The comic might not exist for this date."}
        
        # Extract image URL
        image_url = None
        if comic_img.get('data-srcset'):
            image_url = comic_img['data-srcset'].split(',')[0].split()[0]
            print(f"Debug: Using data-srcset: {image_url}", file=sys.stderr)
        elif comic_img.get('data-src'):
            image_url = comic_img['data-src']
            print(f"Debug: Using data-src: {image_url}", file=sys.stderr)
        elif comic_img.get('src'):
            image_url = comic_img['src']
            print(f"Debug: Using src: {image_url}", file=sys.stderr)
        
        if not image_url:
            return {"success": False, "error": "Could not extract image URL from the image element"}
        
        # Make absolute URL
        if image_url.startswith('//'):
            image_url = 'https:' + image_url
        elif not image_url.startswith('http'):
            image_url = urljoin(url, image_url)
        
        print(f"Debug: Final image URL: {image_url}", file=sys.stderr)
        
        # Create filename
        if date and date != "None" and date != "null":
            clean_date = date.replace('/', '-')
            filename = f"{comic_name}_{clean_date}.png"
        else:
            filename = f"{comic_name}_{datetime.now().strftime('%Y-%m-%d')}.png"
        
        filepath = os.path.join(output_dir, filename)
        
        # Download the image
        print(f"Debug: Downloading image from: {image_url}", file=sys.stderr)
        img_response = requests.get(image_url, headers=headers, timeout=30)
        img_response.raise_for_status()
        
        # Verify it's an image
        content_type = img_response.headers.get('content-type', '')
        if not content_type.startswith('image/'):
            return {"success": False, "error": f"Downloaded content is not an image. Content-Type: {content_type}"}
        
        # Save the image
        with open(filepath, 'wb') as f:
            f.write(img_response.content)
        
        file_size = os.path.getsize(filepath)
        print(f"Debug: Image saved successfully: {filepath} ({file_size} bytes)", file=sys.stderr)
        
        # Get comic title
        title_tag = soup.find('meta', property='og:title')
        title = title_tag['content'] if title_tag else comic_name.replace('-', ' ').title()
        
        # Get date
        date_tag = soup.find('meta', property='article:published_time')
        actual_date = date_tag['content'][:10] if date_tag else (date if date else datetime.now().strftime('%Y-%m-%d'))
        
        return {
            "success": True,
            "filepath": os.path.abspath(filepath),
            "title": title,
            "date": actual_date,
            "url": url
        }
        
    except Exception as e:
        error_msg = f"Download failed: {str(e)}"
        print(f"Error: {error_msg}", file=sys.stderr)
        import traceback
        print(f"Traceback: {traceback.format_exc()}", file=sys.stderr)
        return {"success": False, "error": error_msg}
def download_comicfinal(comic_name, date=None):
	result=download_comic(comic_name, date=None)
	return json.dumps(result)		
	"$
	Dim lstArg As List
	lstArg.Initialize
	lstArg.Add(comicName)  ' First argument
	lstArg.Add(dateValue)    ' Second argument
    
	' Get the Python result as an object first
	Dim pyResult As PyWrapper = Py.RunCode("download_comicfinal", lstArg, code)
	Dim fx As JFX
	
	Wait For (pyResult.Fetch) Complete (pyResult As PyWrapper)
	Log(pyResult.Value)
	' Convert the result to boolean
	Log(pyResult.ErrorMessage)
	' Return the boolean result
	Return pyResult.Value
	
End Sub

Private Sub PrintPythonVersion
	Dim version As PyWrapper = Py.ImportModuleFrom("sys", "version")
	version.Print2("Python version:", "", False)
End Sub
