import urllib.request
import re
import sys

def g(u):
    try:
        headers = {'User-Agent': 'Mozilla/5.0'}
        req = urllib.request.Request(u, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as response:
            html = response.read().decode('utf-8')
            return re.findall(r'photo-([a-zA-Z0-9-]+)\?', html)
    except Exception as e:
        print(f"Error fetching {u}: {e}", file=sys.stderr)
        return []

urls = [
    'https://unsplash.com/s/photos/indian-man-haircut',
    'https://unsplash.com/s/photos/indian-man-hairstyle',
    'https://unsplash.com/s/photos/indian-groom'
]

ids = []
for u in urls:
    ids.extend(g(u))

unique_urls = list(set([f'https://images.unsplash.com/photo-{i}?auto=format&fit=crop&q=80&w=800' for i in ids]))
for url in unique_urls[:40]:
    print(url)
