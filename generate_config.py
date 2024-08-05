from collections import defaultdict
from pathlib import Path

import yaml


class NavBar:
    def __init__(self, base_dir):
        self.base_dir = Path(base_dir)
        if not self.base_dir.is_dir():
            raise ValueError(f"{base_dir} is not a directory")

        self.docs_dir = self.base_dir / "docs"
        if not self.docs_dir.is_dir():
            raise ValueError(f"{self.docs_dir.as_posix()} is not a directory")

        self.nav_dict = {
            "nav": [
                # {"Home": "index.md"},
                {"Blog": "blog/index.md"},
            ]
        }

    def build_nav_structure(self):
        file_structure = defaultdict(lambda: defaultdict(dict))

        for path in self.docs_dir.rglob("*"):
            if (
                path.is_file()
                and path.name != "favicon.ico"
                and path.absolute().as_posix()
                != (self.docs_dir / "index.md").as_posix()
                and path.parent.absolute().as_posix()
                != (self.docs_dir / "blog").as_posix()
            ):
                parts = path.relative_to(self.docs_dir).parts
                current_level = file_structure
                for part in parts[:-1]:
                    current_level = current_level[part]
                current_level[parts[-1].split(".")[0]] = str(
                    path.relative_to(self.docs_dir)
                )

        def recursive_convert(d):
            if isinstance(d, defaultdict):
                converted = {}
                for k, v in d.items():
                    if isinstance(v, dict) and v:
                        converted[k] = recursive_convert(v)
                    else:
                        converted[k] = v
                return converted
            return d

        def convert_to_list_format(d):
            result = []
            for key, value in d.items():
                if isinstance(value, dict):
                    nested_list = convert_to_list_format(value)
                    result.append({key: nested_list})
                else:
                    result.append({key: value})
            return result

        nav_structure_dict = recursive_convert(file_structure)
        nav_structure_list = convert_to_list_format(nav_structure_dict)
        self.nav_dict["nav"].extend(nav_structure_list)

        return self.nav_dict


if __name__ == "__main__":
    BASE_DIR = Path(__file__).parent
    nav_bar = NavBar(BASE_DIR)
    nav_structure = nav_bar.build_nav_structure()
    nav_yaml = yaml.dump(
        nav_structure,
        sort_keys=False,
        default_flow_style=False,
    )
    print(nav_yaml)
    with open(BASE_DIR / "site.yml", mode="r", encoding="utf-8") as f:
        print(f.read())

    # Optional: Save to a YAML file
    # with open('nav.yml', 'w') as f:
    #     f.write(nav_yaml)
