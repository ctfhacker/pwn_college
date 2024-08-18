# pwn.college development environment

Environment used to solve [pwn.college](https://pwn.college) challenges offline.

## Usage

```
nix develop
```

After starting a challenge on [pwn.college](https://pwn.college):

```
nix run .#download
```

Will download all files in `/challenge` to a local `./challenges/CHALLENGE_NAME` folder
