# canWatchDirectoryOrFile

Determines if given directory or file can be watched

## Testing for Posix root: /

| Directory                                                                         | canWatchDirectoryOrFile |
| --------------------------------------------------------------------------------- | ----------------------- |
| /                                                                                 | false                   |
| /folderAtRoot                                                                     | false                   |
| /folderAtRoot/folder1                                                             | false                   |
| /folderAtRoot/folder1/folder2                                                     | false                   |
| /folderAtRoot/folder1/folder2/folder3                                             | true                    |
| /folderAtRoot/folder1/folder2/folder3/folder4                                     | true                    |
| /folderAtRoot/folder1/folder2/folder3/folder4/folder5                             | true                    |
| /users                                                                            | false                   |
| /users/username                                                                   | false                   |
| /users/username/folderAtRoot                                                      | false                   |
| /users/username/folderAtRoot/folder1                                              | true                    |
| /users/username/folderAtRoot/folder1/folder2                                      | true                    |
| /users/username/folderAtRoot/folder1/folder2/folder3                              | true                    |
| /users/username/folderAtRoot/folder1/folder2/folder3/folder4                      | true                    |
| /users/username/folderAtRoot/folder1/folder2/folder3/folder4/folder5              | true                    |
| /user                                                                             | false                   |
| /user/username                                                                    | false                   |
| /user/username/folderAtRoot                                                       | false                   |
| /user/username/folderAtRoot/folder1                                               | true                    |
| /user/username/folderAtRoot/folder1/folder2                                       | true                    |
| /user/username/folderAtRoot/folder1/folder2/folder3                               | true                    |
| /user/username/folderAtRoot/folder1/folder2/folder3/folder4                       | true                    |
| /user/username/folderAtRoot/folder1/folder2/folder3/folder4/folder5               | true                    |
| /usr                                                                              | false                   |
| /usr/username                                                                     | false                   |
| /usr/username/folderAtRoot                                                        | false                   |
| /usr/username/folderAtRoot/folder1                                                | true                    |
| /usr/username/folderAtRoot/folder1/folder2                                        | true                    |
| /usr/username/folderAtRoot/folder1/folder2/folder3                                | true                    |
| /usr/username/folderAtRoot/folder1/folder2/folder3/folder4                        | true                    |
| /usr/username/folderAtRoot/folder1/folder2/folder3/folder4/folder5                | true                    |
| /home                                                                             | false                   |
| /home/username                                                                    | false                   |
| /home/username/folderAtRoot                                                       | false                   |
| /home/username/folderAtRoot/folder1                                               | true                    |
| /home/username/folderAtRoot/folder1/folder2                                       | true                    |
| /home/username/folderAtRoot/folder1/folder2/folder3                               | true                    |
| /home/username/folderAtRoot/folder1/folder2/folder3/folder4                       | true                    |
| /home/username/folderAtRoot/folder1/folder2/folder3/folder4/folder5               | true                    |
| /workspaces                                                                       | false                   |
| /workspaces/folderAtRoot                                                          | false                   |
| /workspaces/folderAtRoot/folder1                                                  | true                    |
| /workspaces/folderAtRoot/folder1/folder2                                          | true                    |
| /workspaces/folderAtRoot/folder1/folder2/folder3                                  | true                    |
| /workspaces/folderAtRoot/folder1/folder2/folder3/folder4                          | true                    |
| /workspaces/folderAtRoot/folder1/folder2/folder3/folder4/folder5                  | true                    |

| File                                                                              | canWatchDirectoryOrFile |
| --------------------------------------------------------------------------------- | ----------------------- |
| /package.json                                                                     | false                   |
| /folderAtRoot/package.json                                                        | false                   |
| /folderAtRoot/folder1/package.json                                                | false                   |
| /folderAtRoot/folder1/folder2/package.json                                        | true                    |
| /folderAtRoot/folder1/folder2/folder3/package.json                                | true                    |
| /folderAtRoot/folder1/folder2/folder3/folder4/package.json                        | true                    |
| /folderAtRoot/folder1/folder2/folder3/folder4/folder5/package.json                | true                    |
| /users/package.json                                                               | false                   |
| /users/username/package.json                                                      | false                   |
| /users/username/folderAtRoot/package.json                                         | true                    |
| /users/username/folderAtRoot/folder1/package.json                                 | true                    |
| /users/username/folderAtRoot/folder1/folder2/package.json                         | true                    |
| /users/username/folderAtRoot/folder1/folder2/folder3/package.json                 | true                    |
| /users/username/folderAtRoot/folder1/folder2/folder3/folder4/package.json         | true                    |
| /users/username/folderAtRoot/folder1/folder2/folder3/folder4/folder5/package.json | true                    |
| /user/package.json                                                                | false                   |
| /user/username/package.json                                                       | false                   |
| /user/username/folderAtRoot/package.json                                          | true                    |
| /user/username/folderAtRoot/folder1/package.json                                  | true                    |
| /user/username/folderAtRoot/folder1/folder2/package.json                          | true                    |
| /user/username/folderAtRoot/folder1/folder2/folder3/package.json                  | true                    |
| /user/username/folderAtRoot/folder1/folder2/folder3/folder4/package.json          | true                    |
| /user/username/folderAtRoot/folder1/folder2/folder3/folder4/folder5/package.json  | true                    |
| /usr/package.json                                                                 | false                   |
| /usr/username/package.json                                                        | false                   |
| /usr/username/folderAtRoot/package.json                                           | true                    |
| /usr/username/folderAtRoot/folder1/package.json                                   | true                    |
| /usr/username/folderAtRoot/folder1/folder2/package.json                           | true                    |
| /usr/username/folderAtRoot/folder1/folder2/folder3/package.json                   | true                    |
| /usr/username/folderAtRoot/folder1/folder2/folder3/folder4/package.json           | true                    |
| /usr/username/folderAtRoot/folder1/folder2/folder3/folder4/folder5/package.json   | true                    |
| /home/package.json                                                                | false                   |
| /home/username/package.json                                                       | false                   |
| /home/username/folderAtRoot/package.json                                          | true                    |
| /home/username/folderAtRoot/folder1/package.json                                  | true                    |
| /home/username/folderAtRoot/folder1/folder2/package.json                          | true                    |
| /home/username/folderAtRoot/folder1/folder2/folder3/package.json                  | true                    |
| /home/username/folderAtRoot/folder1/folder2/folder3/folder4/package.json          | true                    |
| /home/username/folderAtRoot/folder1/folder2/folder3/folder4/folder5/package.json  | true                    |
| /workspaces/package.json                                                          | false                   |
| /workspaces/folderAtRoot/package.json                                             | true                    |
| /workspaces/folderAtRoot/folder1/package.json                                     | true                    |
| /workspaces/folderAtRoot/folder1/folder2/package.json                             | true                    |
| /workspaces/folderAtRoot/folder1/folder2/folder3/package.json                     | true                    |
| /workspaces/folderAtRoot/folder1/folder2/folder3/folder4/package.json             | true                    |
| /workspaces/folderAtRoot/folder1/folder2/folder3/folder4/folder5/package.json     | true                    |

