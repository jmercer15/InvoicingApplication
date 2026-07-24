import subprocess
import json

def get_git_status():
    try:
        res = subprocess.run(['git', 'status', '--porcelain'], capture_output=True, text=True, check=True)
        lines = res.stdout.splitlines()
        
        modified = 0
        deleted = 0
        untracked = 0
        added = 0
        other = 0
        
        for line in lines:
            if not line.strip():
                continue
            status = line[:2]
            if 'M' in status:
                modified += 1
            elif 'D' in status:
                deleted += 1
            elif '??' in status:
                untracked += 1
            elif 'A' in status:
                added += 1
            else:
                other += 1
                
        print(json.dumps({
            "modified": modified,
            "deleted": deleted,
            "untracked": untracked,
            "added": added,
            "other": other,
            "total": len(lines)
        }))
    except Exception as e:
        print(json.dumps({"error": str(e)}))

if __name__ == "__main__":
    get_git_status()
