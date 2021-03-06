#!/bin/sh

# Author:     Héctor Molinero Fernández <hector@molinero.dev>
# Repository: https://github.com/hectorm/hblock
# License:    MIT, https://opensource.org/licenses/MIT

set -eu
export LC_ALL=C

# Check if a program exists
exists() {
	# shellcheck disable=SC2230
	if command -v true; then command -v -- "$1"
	elif eval type type; then eval type -- "$1"
	else which -- "$1"; fi >/dev/null 2>&1
}

# Get file size (or space if it is not a file)
getFileSize() {
	if [ -f "$1" ]; then
		wc -c < "$1" | awk '{printf "%0.2f kB", $1 / 1000}'
	fi
}

# Get file MIME type
getFileType() {
	if exists file; then
		file -bL --mime-type -- "$1"
	else
		printf '%s' 'application/octet-stream'
	fi
}

# Get file modification time
getFileModificationTime() {
	if stat -c '%n' -- "$1" >/dev/null 2>&1; then
		TZ=UTC stat -c '%.19y UTC' -- "$1"
	elif stat -f '%Sm' -t '%Z' -- "$1" >/dev/null 2>&1; then
		TZ=UTC stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S %Z' -- "$1"
	else
		printf '%s' '1970-01-01 00:00:00 UTC'
	fi
}

# Check whether a string ends with the characters of a specified string
endsWith() { str=$1 && substr=$2 && [ "${str%$substr}" != "$str" ]; }

# Escape string for use in HTML
escapeHTML() {
	printf -- '%s' "$1" | awk -v RS="" '{
		gsub(/&/,"\\&#38;");
		gsub(/</,"\\&#60;");
		gsub(/>/,"\\&#62;");
		gsub(/"/,"\\&#34;");
		gsub(/'\''/,"\\&#39;");
		gsub(/\n/,"\\&#10;");
	print}'
}

# RFC 3986 compliant URL encoding method
encodeURI() {
	_LC_COLLATE=${LC_COLLATE-}; LC_COLLATE=C; _IFS=$IFS; IFS=:
	hex=$(printf -- '%s' "$1" | hexdump -ve '/1 ":%02X"'); hex=${hex#:}
	for h in $hex; do
		case "$h" in
			3[0-9]|\
			4[1-9A-F]|5[0-9A]|\
			6[1-9A-F]|7[0-9A]|\
			2D|5F|2E|7E\
			) printf '%b' "\\$(printf '%o' "0x$h")" ;;
			*) printf '%%%s' "$h"
		esac
	done
	LC_COLLATE=$_LC_COLLATE; IFS=$_IFS
}

# Calculate digest for Content-Security-Policy
cspDigest() {
	hex=$(printf -- '%s' "$1" | sha256sum | cut -f1 -d' ' | sed 's|\(.\{2\}\)|\1 |g')
	b64=$(for h in $hex; do printf '%b' "\\$(printf '%o' "0x$h")"; done | base64 | tr -d '\r')
	printf 'sha256-%s' "$b64"
}

main() {
	directory="${1:-./}"

	if ! [ -d "$directory" ] || ! [ -r "$directory" ]; then
		>&2 printf -- '%s\n' "Cannot read directory '$directory'"
		exit 1
	fi

	entries=$(cd -- "$directory" && for file in ./*; do
		if ! [ -r "$file" ] || endsWith "$file" 'index.html'; then
			continue
		fi

		fileName=$(basename "$file")
		escapedFileName=$(escapeHTML "$fileName")
		escapedFileNameURI=$(escapeHTML "$(encodeURI "$fileName")")

		fileSize=$(getFileSize "$file")
		escapedFileSize=$(escapeHTML "$fileSize")

		fileType=$(getFileType "$file")
		escapedFileType=$(escapeHTML "$fileType")

		fileDate=$(getFileModificationTime "$file")
		escapedFileDate=$(escapeHTML "$fileDate")

		# Entry template
		printf -- '%s\n' "$(cat <<-EOF
			<a class="row" href="./${escapedFileNameURI}" title="${escapedFileName}">
				<div class="cell">${escapedFileName}</div>
				<div class="cell">${escapedFileSize}</div>
				<div class="cell">${escapedFileType}</div>
				<div class="cell">${escapedFileDate}</div>
			</a>
		EOF
		)"
	done)

	# Generated with:
	#  $ (printf '%s' 'data:image/png;base64,'; base64 -w0 'resources/logo/bitmap/favicon-32x32.png') | fold -w 128
	favicon=$(tr -d '\n' <<-'EOF'
		data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAA7AAAAOwBeShxvQAAABl0RVh0U2
		9mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAP4SURBVFiFtZdPaBR3FMc/7zdrIy20kJtdaGpddtcGxINVPJlAA0LIQZr0UA+xRfBQKKWHiL2IIuQQCiUJpd1LTg
		ENWgSR2FOTiwRFSKE0brLaliTGVDE0NEt0Z+b1MNmdmd2Z7CbbfmHhzZv3vu/7+/N+81toAppKtWgq1dIMR6KZZNeyRhF5DehvhmdXcLLZr51MRp1MRp1s9sJueWQ3SX
		Y2+5GoTgBmy+WqSF/i4cMf/3cBmk4fdUV+Bl6velU0qh0yP3+/KQFONptDdQ2RJVV9aqmuYMxfOI7linQiMgi8GcP3N3DBOM40ImqLJMWYpKi+A7wNtFj5/GfBhNpNqN
		oFvIsqArgioArG1IRKby8kEujVq2XXW8B3rmUBW+ujGkx5XM0R1QWvYkYXxqFDyKVLnr25id682UhWqdpRO6wGBUh3N1gWWBYyOIgMDcH+/fXSarhrZ0CkVJ426etD+v
		thbQ0SCdwzZ+Dly3JcMAfp6UF6emB5GVZXUdtGWlvRsTH0xo3GBahqqUJtWZBKhQrVRTIJySQhjjJ3QzMQDCqPNgqFAjo+7ulKp+HIkWiBr0I16wswIpta3rnFYmx9nZ
		jwbYDDhzFXroRnDGBjw+eGmhHVbEJVfVqxV1djBdRgdhb33DlYXw/zBThUdaWuAFQXK/ZKTXwYe/d6vzKWl9HR0XDMkye+LbJIFSJOl0DQ8+dg25G15fhxzMwMZmYGOX
		bM1z897QeVSvDixc4EaDDIcby2isKJE/4MdHb6/mfPfHtpCVzX53bdpboCrFLpl5CgBw+iBQSP5qAdLFiVa4nM1hUgjx4tAr9XHPd39HEL49694NO85PNPqkOijmKAqb
		Khd+96S7FT2LaXW4bIdFRY5JVMYVLgU8A7Vu/cQbq7ka4ub2MBtLX5CW1tyMmTnr1nj8cxOeltYp/zp6hakWerdnQk3JWVAuBVOXgQc/166FjdFo6D29sLc3Nlz6LZt+
		89mZqqaanIJZCpKRsRv6Hn5mr7exvoyEiwOIgMRxWPFQBgbDsH/FkhzeXQ27frF791C83lgq4/trii68S9kEJh3cBpwFPuOOjAAHrtWnzx8XH0/PlgK9pG5BMpFNbjcu
		p+X510+itEvgklnTqFXLzoH8PFInr5cvWtSIEvrXx+eDv+hm7FTibzBfBtKP7AAczQELgu7sAAPA5d91zgcyuf/74ed8PXcjuTOS3wA/BGxZnY6uLw9+IfVT2bmJ+PX6
		vdCADQVOp915gJRNpjQn41rvuxLCzMxbyvQewmjIIUCr+ZYvEDVEfYuoeUtQHDZmPj6E6Kwy7/mgGU0ukPjcgYkFDXPZtYWKjfo/81tL29VdvbW5vh+BfQNoY2crpxWA
		AAAABJRU5ErkJggg==
	EOF
	)

	# Generated with:
	#  $ svgo --datauri=enc --output=- 'resources/logo/logotype.svg' | fold -w 128
	logotype=$(tr -d '\n' <<-'EOF'
		data:image/svg+xml,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%221024%22%20height%3D%22320%22%20viewB
		ox%3D%220%200%204000%201250%22%3E%3Cg%20stroke%3D%22%23FD2727%22%20stroke-width%3D%22133.2%22%3E%3Cpath%20fill%3D%22%23FFF%22%20
		d%3D%22M542.134%20130.213c-133.2%20159.839-133.2%20186.479-399.597%20149.183%200%20623.37%20133.2%20676.65%20399.597%20863.128C8
		08.53%20956.046%20941.73%20902.766%20941.73%20279.396c-266.398%2037.296-266.398%2010.656-399.596-149.183z%22%2F%3E%3Cpath%20d%3D
		%22M414.263%20263.412v543.451-165.166a127.87%20127.87%200%200%201%20255.742%200v165.166-165.166%22%20fill%3D%22none%22%2F%3E%3C%
		2Fg%3E%3Cpath%20stroke%3D%22%23FD2727%22%20stroke-width%3D%22155.2%22%20d%3D%22M1318.091%20314.897v609.697V730.6a152.424%20152.4
		24%200%200%201%20304.85%200v193.994V730.6%22%20fill%3D%22none%22%2F%3E%3Cpath%20fill%3D%22%23FD2727%22%20d%3D%22M3480.936%20924.
		594h147.125v-105.09l45.54-50.793%2087.574%20155.883h162.889l-164.64-255.718%20155.882-182.155h-162.889L3631.564%20639.1h-3.503V3
		15.074h-147.125zm-216.009%2010.51c45.54%200%20101.587-12.261%20145.374-50.794l-57.799-98.084c-21.018%2015.764-45.539%2028.024-70
		.06%2028.024-47.29%200-84.071-42.036-84.071-108.593%200-66.556%2033.278-108.592%2089.326-108.592%2015.763%200%2029.775%205.254%2
		049.042%2021.018l70.06-96.332c-33.279-28.024-75.315-45.54-127.86-45.54-124.356%200-234.7%2084.072-234.7%20229.446s96.332%20229.4
		46%20220.688%20229.446zm-494.4%200c112.096%200%20217.185-84.073%20217.185-229.447%200-145.374-105.09-229.445-217.185-229.445s-21
		7.185%2084.071-217.185%20229.445%20105.09%20229.446%20217.185%20229.446zm0-120.854c-45.539%200-63.054-42.036-63.054-108.593%200-
		66.556%2017.515-108.592%2063.054-108.592s63.054%2042.036%2063.054%20108.592c0%2066.557-17.515%20108.593-63.054%20108.593zm-321.2
		49%20120.853c33.279%200%2057.8-5.254%2073.563-12.26l-17.515-110.344c-7.006%201.751-10.509%201.751-15.763%201.751-10.51%200-24.52
		1-8.757-24.521-38.533V315.074h-150.628v455.389c0%2098.083%2033.278%20164.64%20134.864%20164.64zm-657.973-10.509h222.44c122.604%2
		00%20224.191-50.793%20224.191-168.143%200-75.314-43.787-117.35-98.084-133.114v-3.503c43.788-17.515%2071.812-73.563%2071.812-122.
		604%200-112.096-96.333-141.871-215.434-141.871h-204.925zm150.629-346.796v-106.84h50.793c49.042%200%2071.811%2014.011%2071.811%20
		49.041s-22.77%2057.8-71.811%2057.8zm0%20231.198V688.142h61.302c59.55%200%2087.575%2015.764%2087.575%2057.8s-28.024%2063.054-87.5
		75%2063.054z%22%2F%3E%3C%2Fsvg%3E
	EOF
	)

	# JavaScript
	javascript=$(tr -d '\n' <<-'EOF'
		(function(){
		/* This resource is used to check the status of hBlock */
		var c=document.getElementById('status').classList;
		var i=document.createElement('img');c.add('loading');
		i.src='https://hblock-check.molinero.dev/1.png?_='+Date.now();
		i.onload=function(){c.add('disabled');c.remove('loading');};
		i.onerror=function(){c.add('enabled');c.remove('loading');};
		})();
	EOF
	)

	# CSS
	css=$(tr -d '\n' <<-'EOF'
		html {
			font-family: '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif;
			font-size: 16px;
			color: #424242;
			background-color: #FAFAFA;
		}

		a {
			color: #0D47A1;
			text-decoration: none;
		}

		a:hover,
		a:focus {
			text-decoration: underline;
		}

		.container {
			margin: 20px auto;
			width: 100%;
			max-width: 1000px;
		}

		.section {
			margin: 0 10px 10px;
		}

		.title {
			font-weight: 700;
			font-size: 22px;
		}

		.table {
			display: table;
			width: 100%;
			border-collapse: collapse;
			table-layout: fixed;
		}

		.row {
			display: table-row;
		}

		.row:not(:last-child) {
			border-bottom: 1px solid #E0E0E0;
		}

		.row:first-child {
			font-weight: bold;
		}

		a.row {
			color: inherit;
			text-decoration: none;
		}

		a.row:hover,
		a.row:focus {
			background-color: #F5F5F5;
		}

		.cell {
			display: table-cell;
			padding: 15px 10px;
			white-space: pre;
			overflow: hidden;
			text-overflow: ellipsis;
		}

		@media (min-width: 768px) {
			.cell:nth-child(1) { width: 35%; }
			.cell:nth-child(2) { width: 15%; }
			.cell:nth-child(3) { width: 20%; }
			.cell:nth-child(4) { width: 30%; }
		}

		@media (max-width: 767.98px) {
			.table, .row, .cell {
				display: block;
			}

			.row {
				padding: 15px 10px;
			}

			.row:first-child {
				display: none;
			}

			.cell {
				padding: 0 0 5px;
				width: auto;
				white-space: normal;
			}

			.cell::before {
				display: inline-block;
				margin-right: 5px;
				font-weight: bold;
			}

			.cell:nth-child(1)::before {
				content: 'Filename:';
			}

			.cell:nth-child(2)::before {
				content: 'Size:';
			}

			.cell:nth-child(3)::before {
				content: 'Type:';
			}

			.cell:nth-child(4)::before {
				content: 'Modified:';
			}
		}

		#status::before {
			display: inline-block;
			content: '';
		}

		#status:not(.loading):before {
			content: 'It was not possible to determine if you are using hBlock.';
			color: #37474F;
		}

		#status.enabled::before {
			content: 'You are using hBlock.';
			color: #388E3C;
		}

		#status.disabled::before {
			content: 'You are currently not using hBlock.';
			color: #D32F2F;
		}
	EOF
	)

	# Page template
	printf -- '%s\n' "$(tr -d '\n' <<-EOF
		<!DOCTYPE html>
		<html lang="en">

		<head>
			<meta charset="utf-8">
			<meta name="viewport" content="width=device-width, initial-scale=1">

			<meta http-equiv="Content-Security-Policy" content="
				default-src 'none';
				 script-src '$(cspDigest "${javascript}")';
				 style-src '$(cspDigest "${css}")';
				 img-src data: https://hblock-check.molinero.dev/1.png;
			">

			<title>Index of /hBlock</title>
			<meta name="description" content="Improve your security and privacy by blocking ads, tracking and malware domains">
			<meta name="author" content="Héctor Molinero Fernández <hector@molinero.dev>">
			<meta name="license" content="MIT, https://opensource.org/licenses/MIT">
			<link rel="canonical" href="https://hblock.molinero.dev/">

			<link rel="icon" type="image/png" href="${favicon}">

			<!-- See: http://ogp.me -->
			<meta property="og:title" content="Index of /hBlock">
			<meta property="og:description" content="Improve your security and privacy by blocking ads, tracking and malware domains">
			<meta property="og:type" content="website">
			<meta property="og:url" content="https://hblock.molinero.dev/">
			<meta property="og:image" content="https://raw.githubusercontent.com/hectorm/hblock/master/resources/logo/bitmap/favicon-512x512.png">

			<style>${css}</style>
		</head>

		<body>
			<div class="container">
				<div class="section">
					<a title="hBlock project page" href="https://github.com/hectorm/hblock">
						<img src="${logotype}" width="160" height="50" alt="hBlock">
					</a>
					<p>
						hBlock is a POSIX-compliant shell script, designed for Unix-like systems, that gets a list of domains that serve ads, tracking
						 scripts and malware from <a title="hBlock sources" href="https://github.com/hectorm/hblock#sources">multiple sources</a>
						 and creates a <a title="hosts file definition" href="https://en.wikipedia.org/wiki/Hosts_(file)">hosts file</a>
						 (alternative formats are also supported) that prevents your system from connecting to them.
					</p>
					<p>
						On this website you can download the latest build of the default blocklist and you can generate your own by following the
						 instructions on the project page
						 (<a title="hBlock project page" href="https://github.com/hectorm/hblock">github.com/hectorm/hblock</a>).
					</p>
				</div>
				<div class="section">
					<h2 class="title">Status</h2>
					 <span id="status"></span>
				</div>
				<div class="section">
					<h2 class="title">Latest build ($(date '+%Y-%m-%d'))</h2>
					<div class="table">
						<div class="row">
							<div class="cell">Filename</div>
							<div class="cell">Size</div>
							<div class="cell">Type</div>
							<div class="cell">Modified</div>
						</div>
						${entries}
					</div>
				</div>
			</div>
			<script>${javascript}</script>
		</body>

		</html>
	EOF
	)"
}

main "$@"
