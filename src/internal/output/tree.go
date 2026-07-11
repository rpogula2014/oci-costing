package output

import (
	"fmt"
	"path/filepath"
	"sort"
)

type FileResult struct {
	Path   string
	Status string // "DONE", "SKIP", "FAIL"
	Rows   int
	Group  string // optional grouping label; if empty, uses directory
}

func PrintTree(root string, results []FileResult) {
	type dirInfo struct {
		files []FileResult
	}
	dirs := make(map[string]*dirInfo)

	for _, r := range results {
		var groupKey string
		if r.Group != "" {
			groupKey = r.Group
		} else {
			rel, _ := filepath.Rel(root, r.Path)
			if rel == "" {
				rel = r.Path
			}
			groupKey = filepath.Dir(rel)
		}
		if dirs[groupKey] == nil {
			dirs[groupKey] = &dirInfo{}
		}
		dirs[groupKey].files = append(dirs[groupKey].files, r)
	}

	dirNames := make([]string, 0, len(dirs))
	for d := range dirs {
		dirNames = append(dirNames, d)
	}
	sort.Strings(dirNames)

	var totalDone, totalSkip, totalRows int
	for _, r := range results {
		switch r.Status {
		case "DONE":
			totalDone++
			totalRows += r.Rows
		case "SKIP":
			totalSkip++
		}
	}

	fmt.Println()
	fmt.Printf("%s\n", root)

	flat := len(dirNames) == 1 && dirNames[0] == "."

	for di, dir := range dirNames {
		info := dirs[dir]
		isLastDir := di == len(dirNames)-1

		var fileTreePrefix string
		if flat {
			fileTreePrefix = ""
		} else {
			dirPrefix := "├── "
			fileTreePrefix = "│   "
			if isLastDir {
				dirPrefix = "└── "
				fileTreePrefix = "    "
			}
			fmt.Printf("%s%s/\n", dirPrefix, dir)
		}

		for fi, f := range info.files {
			isLastFile := fi == len(info.files)-1
			filePrefix := fileTreePrefix + "├── "
			if isLastFile {
				filePrefix = fileTreePrefix + "└── "
			}
			name := filepath.Base(f.Path)
			switch f.Status {
			case "DONE":
				fmt.Printf("%s%s  ✓ %d rows\n", filePrefix, name, f.Rows)
			case "SKIP":
				fmt.Printf("%s%s  ⊘ already loaded\n", filePrefix, name)
			case "FAIL":
				fmt.Printf("%s%s  ✗ failed\n", filePrefix, name)
			}
		}
	}
	fmt.Println()
	fmt.Printf("Summary: %d loaded (%d rows), %d skipped, %d total files\n",
		totalDone, totalRows, totalSkip, len(results))
}
