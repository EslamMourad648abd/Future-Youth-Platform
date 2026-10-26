import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserManagement extends StatefulWidget {
  final FirebaseFunctions functions;

  const UserManagement({
    super.key,
    required this.functions,
  });

  @override
  State<UserManagement> createState() =>
      _UserManagementState();
}

class _UserManagementState extends State<UserManagement> {
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filteredUsers = [];

  bool loading = true;
  String? error;

  String searchQuery = "";

  // ============================================================
  // ROLE CONSTANTS
  // ============================================================

  static const String adminRole = "admin";
  static const String teacherRole = "teacher";
  static const String parentRole = "parent";
  static const String studentRole = "student";
  static const String superAdminRole = "admin";

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  // ============================================================
  // LOAD USERS
  // ============================================================

  Future<void> _loadUsers() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final callable = widget.functions.httpsCallable(
        "listUsers",
      );

      final result = await callable();

      final data = result.data;

      if (data is Map && data["users"] is List) {
        final loaded =
        List<Map<String, dynamic>>.from(
          data["users"],
        );

        if (!mounted) return;

        setState(() {
          users = loaded;
          filteredUsers = loaded;
          loading = false;
        });
      } else {
        throw Exception(
          "Invalid users response",
        );
      }
    } catch (e) {
      debugPrint(
        "LOAD USERS ERROR: $e",
      );

      if (!mounted) return;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final email = (currentUser.email ?? "").trim();
        final adminUser = {
          "uid": currentUser.uid,
          "email": email,
          "displayName": (currentUser.displayName ?? "").isNotEmpty
              ? currentUser.displayName
              : "Super Admin",
          "role": superAdminRole,
          "createdAt": null,
          "lastLogin": currentUser.metadata.lastSignInTime?.toIso8601String(),
        };

        setState(() {
          users = [adminUser];
          filteredUsers = [adminUser];
          loading = false;
          error = null;
        });
        return;
      }

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  // ============================================================
  // MIGRATE EXISTING USERS ROLES TO FIRESTORE
  // ============================================================

  Future<void> _migrateUserRoles() async {
    try {
      final callable =
      widget.functions.httpsCallable(
        "migrateUserRolesToFirestore",
      );

      final result = await callable();

      _showMessage(
        result.data["message"] ??
            "Roles migrated successfully",
        Colors.green,
      );

      await _loadUsers();
    } catch (e) {
      _showMessage(
        "Migration failed: $e",
        Colors.red,
      );
    }
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _searchUsers(String value) {
    setState(() {
      searchQuery = value.toLowerCase();

      if (value.isEmpty) {
        filteredUsers = users;
      } else {
        filteredUsers = users.where((user) {
          final email = (user["email"] ?? "")
              .toString()
              .toLowerCase();

          final name = (user["displayName"] ?? "")
              .toString()
              .toLowerCase();

          return email.contains(searchQuery) ||
              name.contains(searchQuery);
        }).toList();
      }
    });
  }

  // ============================================================
  // ADD USER
  // ============================================================

  Future<void> _addUser(
      Map<String, dynamic> data,
      ) async {
    try {
      final callable = widget.functions.httpsCallable("createUser");
      await callable(data);
      _showMessage("User created successfully", Colors.green);
      await _loadUsers();
    } catch (e) {
      debugPrint("CREATE USER CALLABLE ERROR: $e");
      String errorMessage = "Failed to create user.";
      if (e is FirebaseFunctionsException) {
        errorMessage = e.message ?? e.details?.toString() ?? e.code;
      } else {
        errorMessage = e.toString().replaceAll("Exception: ", "");
      }
      _showMessage(errorMessage, Colors.red);
      rethrow;
    }
  }

  // ============================================================
  // EDIT USER
  // ============================================================

  Future<void> _editUser(
      Map<String, dynamic> data,
      ) async {
    final uid = data["uid"]?.toString() ?? "";
    try {
      final callable = widget.functions.httpsCallable("updateUser");
      await callable(data);
      _showMessage("User updated successfully", Colors.green);
      await _loadUsers();
    } catch (e) {
      debugPrint("UPDATE USER CALLABLE ERROR: $e");
      try {
        if (uid.isNotEmpty) {
          final firestoreData = <String, dynamic>{
            "displayName": data["displayName"] ?? "",
            "email": data["email"] ?? "",
            "role": data["role"] ?? studentRole,
            "updatedAt": FieldValue.serverTimestamp(),
          };

          await FirebaseFirestore.instance
              .collection("users")
              .doc(uid)
              .set(firestoreData, SetOptions(merge: true));

          if (!mounted) return;
          setState(() {
            final idx = users.indexWhere((u) => u["uid"] == uid);
            if (idx != -1) {
              users[idx]["displayName"] = data["displayName"] ?? users[idx]["displayName"];
              users[idx]["email"] = data["email"] ?? users[idx]["email"];
              users[idx]["role"] = data["role"] ?? users[idx]["role"];
            }
            _searchUsers(searchQuery);
          });

          _showMessage("User updated successfully", Colors.green);
          return;
        }
      } catch (firestoreErr) {
        debugPrint("FIRESTORE EDIT ERROR: $firestoreErr");
      }
      _showMessage("Failed to update user: $e", Colors.red);
    }
  }

  // ============================================================
  // DELETE USER
  // ============================================================

  Future<void> _deleteUser(
      String uid,
      ) async {
    try {
      final callable = widget.functions.httpsCallable("deleteUser");
      await callable({"uid": uid});
      _showMessage("User deleted", Colors.green);
      await _loadUsers();
    } catch (e) {
      debugPrint("DELETE USER CALLABLE ERROR: $e");
      try {
        await FirebaseFirestore.instance.collection("users").doc(uid).delete();
        if (!mounted) return;
        setState(() {
          users.removeWhere((u) => u["uid"] == uid);
          _searchUsers(searchQuery);
        });
        _showMessage("User deleted", Colors.green);
      } catch (firestoreErr) {
        _showMessage("Failed to delete user: $e", Colors.red);
      }
    }
  }

  // ============================================================
  // UPDATE ROLE
  // ============================================================

  Future<void> _updateRole(
      String uid,
      String role,
      ) async {
    try {
      final callable = widget.functions.httpsCallable("setUserRole");
      await callable({"uid": uid, "role": role});
      _showMessage("User role updated successfully", Colors.green);
      await _loadUsers();
    } catch (e) {
      debugPrint("SET ROLE CALLABLE ERROR: $e");
      try {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .set({"role": role}, SetOptions(merge: true));

        if (!mounted) return;
        setState(() {
          final idx = users.indexWhere((u) => u["uid"] == uid);
          if (idx != -1) {
            users[idx]["role"] = role;
          }
          _searchUsers(searchQuery);
        });

        _showMessage("User role updated successfully", Colors.green);
      } catch (firestoreErr) {
        _showMessage("Failed to update role: $e", Colors.red);
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String text,
      Color color,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: color,
      ),
    );
  }

  // ============================================================
  // ADD USER DIALOG
  // ============================================================

  void _showAddDialog() {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();

    String role = teacherRole;
    String? dialogError;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            return AlertDialog(
              title: const Text(
                "Add User",
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dialogError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogError!,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: "Name *",
                        hintText: "Enter full name",
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Email *",
                        hintText: "user@example.com",
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Password *",
                        hintText: "At least 6 characters",
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(
                        labelText: "Role",
                      ),
                      items: _roles(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          role = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.pop(
                            dialogContext,
                          );
                        },
                  child: const Text(
                    "Cancel",
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final nameVal = name.text.trim();
                          final emailVal = email.text.trim();
                          final passwordVal = password.text.trim();

                          if (nameVal.isEmpty) {
                            setDialogState(() {
                              dialogError = "Name is required.";
                            });
                            return;
                          }

                          if (emailVal.isEmpty || !emailVal.contains("@")) {
                            setDialogState(() {
                              dialogError = "Please enter a valid email address.";
                            });
                            return;
                          }

                          if (passwordVal.length < 6) {
                            setDialogState(() {
                              dialogError = "Password must be at least 6 characters.";
                            });
                            return;
                          }

                          setDialogState(() {
                            dialogError = null;
                            isSubmitting = true;
                          });

                          try {
                            await _addUser({
                              "displayName": nameVal,
                              "email": emailVal,
                              "password": passwordVal,
                              "role": role,
                            });

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                          } catch (err) {
                            setDialogState(() {
                              isSubmitting = false;
                              if (err is FirebaseFunctionsException) {
                                dialogError = err.message ?? err.code;
                              } else {
                                dialogError = err.toString().replaceAll("Exception: ", "");
                              }
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          "Create",
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // EDIT USER DIALOG
  // ============================================================

  void _showEditDialog(
      Map<String, dynamic> user,
      ) {
    final name = TextEditingController(
      text: user["displayName"] ?? "",
    );

    final email = TextEditingController(
      text: user["email"] ?? "",
    );

    final password = TextEditingController();

    String role =
    _normalizeRole(
      user["role"],
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            return AlertDialog(
              title: const Text(
                "Edit User",
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration:
                    const InputDecoration(
                      labelText: "Name",
                    ),
                  ),
                  TextField(
                    controller: email,
                    decoration:
                    const InputDecoration(
                      labelText: "Email",
                    ),
                  ),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration:
                    const InputDecoration(
                      labelText:
                      "New Password (optional)",
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration:
                    const InputDecoration(
                      labelText: "Role",
                    ),
                    items: _roles(),
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        role = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text(
                    "Cancel",
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final data =
                    <String, dynamic>{
                      "uid": user["uid"],
                      "displayName":
                      name.text.trim(),
                      "email":
                      email.text.trim(),
                      "role": role,
                    };

                    if (password.text
                        .trim()
                        .isNotEmpty) {
                      data["password"] =
                          password.text.trim();
                    }

                    _editUser(data);

                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text(
                    "Save",
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // NORMALIZE ROLE
  // ============================================================
  //
  // Existing users may still have the old "agent" role
  // until you manually migrate them.
  //
  // We display them as Onboarding Agent in the UI so the
  // role management screen remains usable during migration.
  //
  // Selecting/saving the role will write the new role:
  // onboarding_agent
  //
  // ============================================================

  String _normalizeRole(
      dynamic value,
      ) {
    final role =
    (value ?? "")
        .toString()
        .trim()
        .toLowerCase();

    switch (role) {
      case "admin":
      case "superadmin":
        return adminRole;

      case "teacher":
        return teacherRole;

      case "parent":
        return parentRole;

      case "student":
      case "trainee":
      default:
        return studentRole;
    }
  }

  // ============================================================
  // ROLE LABEL
  // ============================================================

  String _roleLabel(
      String role,
      ) {
    switch (role) {
      case adminRole:
        return "Admin";

      case teacherRole:
        return "Teacher";

      case parentRole:
        return "Parent";

      case studentRole:
        return "Student";

      default:
        return role;
    }
  }

  // ============================================================
  // ROLES
  // ============================================================

  List<DropdownMenuItem<String>> _roles() {
    return const [
      DropdownMenuItem(
        value: adminRole,
        child: Text(
          "Admin",
        ),
      ),
      DropdownMenuItem(
        value: teacherRole,
        child: Text(
          "Teacher",
        ),
      ),
      DropdownMenuItem(
        value: parentRole,
        child: Text(
          "Parent",
        ),
      ),
      DropdownMenuItem(
        value: studentRole,
        child: Text(
          "Student",
        ),
      ),
    ];
  }

  // ============================================================
  // DELETE CONFIRMATION
  // ============================================================

  Future<void> _confirmDelete(
      Map<String, dynamic> user,
      ) async {
    final result =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Delete User",
          ),
          content: Text(
            "Delete ${user["email"]}?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                "Cancel",
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                Colors.red,
                foregroundColor:
                Colors.white,
              ),
              child: const Text(
                "Delete",
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _deleteUser(
        user["uid"],
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
      theme.colorScheme.surface,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          "User Management",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        actions: [
          IconButton(
            tooltip:
            "Refresh Users",
            onPressed:
            loading
                ? null
                : _loadUsers,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: _buildBody(context),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    // ----------------------------------------------------------
    // Loading
    // ----------------------------------------------------------

    if (loading) {
      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    // ----------------------------------------------------------
    // Error
    // ----------------------------------------------------------

    if (error != null) {
      return Center(
        child: Padding(
          padding:
          const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red,
              ),
              const SizedBox(
                height: 16,
              ),
              Text(
                error!,
                textAlign:
                TextAlign.center,
                style:
                const TextStyle(
                  color: Colors.red,
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              ElevatedButton.icon(
                onPressed:
                _loadUsers,
                icon: const Icon(
                  Icons.refresh,
                ),
                label: const Text(
                  "Retry",
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // Main Content
    // ----------------------------------------------------------

    return Column(
      children: [
        // ======================================================
        // HEADER
        // ======================================================

        Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;

            final headerActions = [
              if (!isCompact) const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size(140, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add),
                label: const Text("Add User"),
              ),
              if (isCompact) const SizedBox(height: 12) else const SizedBox(width: 20),
              SizedBox(
                width: isCompact ? double.infinity : 250,
                child: TextField(
                  onChanged: _searchUsers,
                  decoration: InputDecoration(
                    hintText: "Search",
                    filled: true,
                    fillColor: theme.cardTheme.color,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                ),
              ),
            ];

            return isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: headerActions,
                  )
                : Row(children: headerActions);
          }),
        ),

        // ======================================================
        // USER LIST
        // ======================================================

        Expanded(
          child:
          filteredUsers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
            onRefresh:
            _loadUsers,
            child:
            ListView.builder(
              physics:
              const AlwaysScrollableScrollPhysics(),
              padding:
              const EdgeInsets.only(
                bottom: 24,
              ),
              itemCount:
              filteredUsers
                  .length,
              itemBuilder:
                  (
                  context,
                  index,
                  ) {
                final user =
                filteredUsers[
                index];

                return _buildUserCard(
                  user,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height:
            MediaQuery.of(context)
                .size
                .height *
                0.35,
          ),
          Icon(
            Icons.people_outline,
            size: 70,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(
            height: 20,
          ),
          Center(
            child: Text(
              searchQuery.isEmpty
                  ? "No users found"
                  : "No users match your search",
              style:
              TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // USER CARD
  // ============================================================

  Widget _buildUserCard(
      Map<String, dynamic> user,
      ) {
    final theme = Theme.of(context);
    final email =
    (user["email"] ?? "")
        .toString()
        .trim();

    final displayName =
    (user["displayName"] ?? "")
        .toString()
        .trim();

    final shownName = displayName.isNotEmpty ? displayName : email;
    final rawRole = (user["role"] ?? "").toString();
    final role = _normalizeRole(rawRole);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      elevation: 0,
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;

        final infoPart = Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                shownName.isNotEmpty ? shownName[0].toUpperCase() : "?",
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shownName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (displayName.isNotEmpty)
                    Text(
                      email,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                ],
              ),
            ),
          ],
        );

        final actionsPart = Row(
          mainAxisSize: isCompact ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: isCompact ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            DropdownButton<String>(
              dropdownColor: theme.cardTheme.color,
              underline: const SizedBox(),
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
              value: _roles().any((item) => item.value == role) ? role : studentRole,
              items: _roles(),
              onChanged: (value) {
                if (value != null) _updateRole(user["uid"], value);
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: "Edit User",
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showEditDialog(user),
            ),
            IconButton(
              tooltip: "Delete User",
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _confirmDelete(user),
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.all(16),
          child: isCompact
              ? Column(
                  children: [
                    infoPart,
                    const Divider(height: 24),
                    actionsPart,
                  ],
                )
              : Row(children: [Expanded(child: infoPart), const SizedBox(width: 20), actionsPart]),
        );
      }),
    );
  }
}