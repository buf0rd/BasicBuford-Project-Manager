#!/bin/bash

# Update and upgrade the system
echo "Updating the system..."
sudo apt update && sudo apt upgrade -y

# Install Apache and PHP
echo "Installing Apache and PHP..."
sudo apt install -y apache2 php libapache2-mod-php

# Install additional PHP extensions
echo "Installing additional PHP extensions..."
sudo apt install -y php-json php-mbstring

# Enable Apache rewrite module
echo "Enabling Apache rewrite module..."
sudo a2enmod rewrite

# Configure Apache to allow .htaccess
echo "Configuring Apache..."
echo "<Directory /var/www/html>
    AllowOverride All
</Directory>" | sudo tee -a /etc/apache2/apache2.conf

# Restart Apache to apply changes
echo "Restarting Apache..."
sudo systemctl restart apache2

# Create project directory
PROJECT_DIR="/var/www/html/basicb_project_manager"
echo "Creating project directory at $PROJECT_DIR..."
sudo mkdir -p "$PROJECT_DIR"

# Create tasks.json file
echo "Creating tasks.json file..."
echo "[]" | sudo tee "$PROJECT_DIR/tasks.json"


# Set permissions
echo "Setting permissions..."
sudo chown -R www-data:www-data /var/www/html/basicb_project_manager
sudo chmod -R 755 /var/www/html/basicb_project_manager

# Create index.php file
cat << 'EOF' | sudo tee "$PROJECT_DIR/index.php"
<?php
// Enable error reporting for debugging
ini_set('display_errors', 1);
error_reporting(E_ALL);

// File to store tasks
$taskFile = 'tasks.json';

// Load tasks from JSON file
function loadTasks() {
    global $taskFile;
    if (!file_exists($taskFile)) {
        file_put_contents($taskFile, json_encode([]));
    }
    $json = file_get_contents($taskFile);
    return json_decode($json, true) ?: []; // Ensure it returns an array
}

// Save tasks to JSON file
function saveTasks($tasks) {
    global $taskFile;
    file_put_contents($taskFile, json_encode($tasks, JSON_PRETTY_PRINT));
}

// Handle adding a new task
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    $title = trim($_POST['title']);
    $assignedTo = trim($_POST['assignedTo']);
    $creator = trim($_POST['creator']);
    $eta = $_POST['eta'];
    $priority = $_POST['priority'];

    if (!empty($title) && !empty($assignedTo) && !empty($creator) && !empty($eta) && !empty($priority)) {
        $tasks = loadTasks();

        if ($_POST['action'] === 'add') {
            // Adding a new task
            $tasks[] = [
                'title' => $title,
                'assigned_to' => $assignedTo,
                'creator' => $creator,
                'eta' => $eta,
                'priority' => $priority
            ];
            saveTasks($tasks);
        } elseif ($_POST['action'] === 'edit' && isset($_POST['id'])) {
            // Editing an existing task
            $id = $_POST['id'];
            if (isset($tasks[$id])) {
                $tasks[$id] = [
                    'title' => $title,
                    'assigned_to' => $assignedTo,
                    'creator' => $creator,
                    'eta' => $eta,
                    'priority' => $priority
                ];
                saveTasks($tasks);
            }
        }

        // Redirect to the same page to show the updated task
        header('Location: ' . $_SERVER['PHP_SELF']);
        exit();
    }
}

// Handle deleting a task
if (isset($_GET['delete'])) {
    $id = $_GET['delete'];
    $tasks = loadTasks();
    if (isset($tasks[$id])) {  // Check if the task exists
        array_splice($tasks, $id, 1); // Remove the task
        saveTasks($tasks);
    }
}

// Handle moving tasks up or down
if (isset($_GET['move'])) {
    $tasks = loadTasks();
    $id = $_GET['move'];
    if (isset($tasks[$id])) {
        if (isset($_GET['direction']) && $_GET['direction'] == 'up' && $id > 0) {
            // Move up
            $temp = $tasks[$id];
            $tasks[$id] = $tasks[$id - 1];
            $tasks[$id - 1] = $temp;
        } elseif (isset($_GET['direction']) && $_GET['direction'] == 'down' && $id < count($tasks) - 1) {
            // Move down
            $temp = $tasks[$id];
            $tasks[$id] = $tasks[$id + 1];
            $tasks[$id + 1] = $temp;
        }
        saveTasks($tasks);
    }
}

// Fetch tasks
$tasks = loadTasks();
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>BasicB Project Manager</title>
    <style>
        body {
            background-color: #1e1e1e;
            color: #00ffcc;
            font-family: 'Courier New', Courier, monospace;
            margin: 0;
            padding: 20px;
        }
        h1, h2 {
            text-align: center;
        }
        input, button, select {
            width: 100%;
            padding: 10px;
            margin: 5px 0;
            border: none;
            border-radius: 5px;
            font-size: 16px;
        }
        button {
            background-color: #00ffcc;
            color: #1e1e1e;
            cursor: pointer;
        }
        .task {
            border: 1px solid #00ffcc;
            padding: 15px;
            margin: 10px 0;
            border-radius: 5px;
            background-color: rgba(0, 255, 204, 0.1);
            display: flex;
            justify-content: space-between; /* Aligns children in a row */
            align-items: center; /* Vertically centers children */
        }
        .task h3 {
            margin: 0;
            flex-grow: 1; /* Allows title to take up available space */
        }
        .task p {
            margin: 5px 0;
        }
        .countdown {
            font-weight: bold;
        }
        .low {
            color: green;
        }
        .medium {
            color: orange;
        }
        .high {
            color: red;
        }
        .task-actions {
            display: flex;
            flex-direction: column; /* Stack buttons vertically */
        }
        .task-actions button {
            width: auto; /* Allow buttons to be as wide as content */
            margin-left: 5px; /* Add space between buttons */
        }
        .new-task {
            margin-top: 20px; /* Space above the new task input */
        }
        .edit-form {
            display: none; /* Hide edit form initially */
            margin-top: 20px;
            background-color: rgba(0, 255, 204, 0.1);
            padding: 15px;
            border-radius: 5px;
        }
        .add-task-form {
            display: none; /* Hide the add task form initially */
            margin-top: 20px;
            background-color: rgba(0, 255, 204, 0.1);
            padding: 15px;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <h1>BasicB Project Manager</h1>

    <h2>Tasks</h2>
    <div id="taskList">
        <?php if (count($tasks) > 0): ?>
            <?php foreach ($tasks as $index => $task): ?>
                <div class="task <?php echo htmlspecialchars($task['priority']); ?>">
                    <div>
                        <h3><?php echo htmlspecialchars($task['title']); ?></h3>
                        <p>Assigned To: <?php echo htmlspecialchars($task['assigned_to']); ?></p>
                        <p>Created By: <?php echo htmlspecialchars($task['creator'] ?? 'N/A'); ?></p> <!-- Default to 'N/A' if null -->
                        <p>ETA: <span class="countdown" id="countdown-<?php echo $index; ?>"></span></p>
                        <p>Priority: <?php echo htmlspecialchars(ucfirst($task['priority'])); ?></p>
                    </div>
                    <div class="task-actions">
                        <a href="?delete=<?php echo $index; ?>">
                            <button>Delete</button>
                        </a>
                        <a href="?move=<?php echo $index; ?>&direction=up">
                            <button>↑</button>
                        </a>
                        <a href="?move=<?php echo $index; ?>&direction=down">
                            <button>↓</button>
                        </a>
                        <button onclick="showEditForm(<?php echo $index; ?>, '<?php echo addslashes($task['title']); ?>', '<?php echo addslashes($task['assigned_to']); ?>', '<?php echo addslashes($task['creator'] ?? 'N/A'); ?>', '<?php echo $task['eta']; ?>', '<?php echo htmlspecialchars($task['priority']); ?>')">Edit</button>
                    </div>
                </div>

                <script>
                    (function() {
                        const countdownElement = document.getElementById("countdown-<?php echo $index; ?>");
                        const countDownDate = new Date("<?php echo $task['eta']; ?>").getTime();

                        const countdownInterval = setInterval(function() {
                            const now = new Date().getTime();
                            const distance = countDownDate - now;

                            const days = Math.floor(distance / (1000 * 60 * 60 * 24));
                            const hours = Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
                            const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
                            const seconds = Math.floor((distance % (1000 * 60)) / 1000);

                            countdownElement.innerHTML = `${days}d ${hours}h ${minutes}m ${seconds}s`;

                            if (distance < 0) {
                                clearInterval(countdownInterval);
                                countdownElement.innerHTML = "EXPIRED";
                            } else if (days < 1) {
                                countdownElement.style.color = "red"; // Change to red as deadline approaches
                            } else if (days < 3) {
                                countdownElement.style.color = "orange"; // Change to orange as it gets closer
                            } else {
                                countdownElement.style.color = "green"; // Default color
                            }
                        }, 1000);
                    })();
                </script>
            <?php endforeach; ?>
        <?php else: ?>
            <p>No tasks found. Please add a task below.</p>
        <?php endif; ?>
    </div>

    <button id="toggleAddTaskButton">Add New Task</button>
    <div class="add-task-form" id="addTaskForm">
        <h2>Add New Task</h2>
        <form method="POST">
            <input type="text" name="creator" placeholder="Project Creator" required>
            <input type="text" name="assignedTo" placeholder="Assignee" required>
            <input type="text" name="title" placeholder="Task Title" required>
            <input type="datetime-local" name="eta" required>
            <select name="priority" required>
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
            </select>
            <input type="hidden" name="action" value="add">
            <button type="submit">Add Task</button>
        </form>
    </div>

    <div id="editForm" class="edit-form">
        <h2>Edit Task</h2>
        <form id="taskEditForm" method="POST">
            <input type="text" name="creator" id="editCreator" placeholder="Project Creator" required>
            <input type="text" name="assignedTo" id="editAssignedTo" placeholder="Assignee" required>
            <input type="text" name="title" id="editTitle" placeholder="Task Title" required>
            <input type="datetime-local" name="eta" id="editETA" required>
            <select name="priority" id="editPriority" required>
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
            </select>
            <input type="hidden" name="id" id="editId">
            <input type="hidden" name="action" value="edit">
            <button type="submit">Update Task</button>
        </form>
    </div>

    <script>
        function showEditForm(index, title, assignedTo, creator, eta, priority) {
            document.getElementById('editId').value = index;
            document.getElementById('editTitle').value = title;
            document.getElementById('editAssignedTo').value = assignedTo;
            document.getElementById('editCreator').value = creator;
            document.getElementById('editETA').value = eta;
            document.getElementById('editPriority').value = priority;
            document.getElementById('editForm').style.display = 'block'; // Show the edit form
        }

        // Toggle Add New Task Form
        document.getElementById('toggleAddTaskButton').onclick = function() {
            const addTaskForm = document.getElementById('addTaskForm');
            if (addTaskForm.style.display === 'none' || addTaskForm.style.display === '') {
                addTaskForm.style.display = 'block'; // Show the form
            } else {
                addTaskForm.style.display = 'none'; // Hide the form
            }
        };
    </script>
</body>
</html>
EOF




# Output completion message
echo "Setup complete! Your BasicB Project Manager is ready at http://YOUR-HOST-IP-ADDRESS/basicb_project_manager/"
