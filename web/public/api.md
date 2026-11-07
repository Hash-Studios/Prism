# Prism Wallpapers API summary

The public API base URL is `https://prismwalls.com/api/v1`. Public catalog reads require no authentication. See [/docs](/docs) for endpoint details and [/openapi.json](/openapi.json) for the machine-readable description.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/api/v1/wallpapers` | Browse or search wallpapers with `q` |
| GET | `/api/v1/wallpapers/{id}` | Fetch one wallpaper |
| GET | `/api/v1/categories` | List categories |
| GET | `/api/v1/pricing` | Read plan information |
| GET | `/api/v1/sandbox/wallpapers` | Test with sandbox data |

Errors are JSON objects with an `error` value containing a stable `code` and human-readable `message`. Check HTTP status codes, pace requests, and expect sandbox data or limits to differ from production. Wallpaper availability does not grant permission to redistribute an image.
