<?php
session_start();
require_once __DIR__ . '/config.php';

// Handle login
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['login'])) {
    $db = getDB();
    $stmt = $db->prepare('SELECT * FROM admin_users WHERE username = ?');
    $stmt->execute([$_POST['username']]);
    $user = $stmt->fetch();
    
    if ($user && password_verify($_POST['password'], $user['password'])) {
        $_SESSION['admin'] = $user['username'];
        header('Location: admin.php');
        exit;
    } else {
        $loginError = 'Invalid username or password';
    }
}

// Handle logout
if (isset($_GET['logout'])) {
    session_destroy();
    header('Location: admin.php');
    exit;
}

// Handle delete
if (isset($_GET['delete']) && isset($_SESSION['admin'])) {
    $db = getDB();
    $stmt = $db->prepare('DELETE FROM sos_alerts WHERE id = ?');
    $stmt->execute([$_GET['delete']]);
    header('Location: admin.php');
    exit;
}

// Handle change password
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['change_password']) && isset($_SESSION['admin'])) {
    $db = getDB();
    $newHash = password_hash($_POST['new_password'], PASSWORD_DEFAULT);
    $stmt = $db->prepare('UPDATE admin_users SET password = ? WHERE username = ?');
    $stmt->execute([$newHash, $_SESSION['admin']]);
    $passMsg = 'Password updated successfully!';
}

$isLoggedIn = isset($_SESSION['admin']);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Seyyon Admin Panel</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f0fdf4; color: #1a1a1a; }
        
        .header { background: linear-gradient(135deg, #10B981, #065F46); color: white; padding: 20px 30px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 4px 20px rgba(16,185,129,0.3); }
        .header h1 { font-size: 24px; letter-spacing: 1px; }
        .header span { font-size: 12px; opacity: 0.8; letter-spacing: 3px; }
        .header a { color: white; text-decoration: none; background: rgba(255,255,255,0.2); padding: 8px 16px; border-radius: 8px; font-size: 14px; }
        .header a:hover { background: rgba(255,255,255,0.3); }
        
        .container { max-width: 1200px; margin: 0 auto; padding: 24px; }
        
        /* Stats Cards */
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 24px; }
        .stat-card { background: white; border-radius: 14px; padding: 20px; box-shadow: 0 2px 12px rgba(0,0,0,0.06); }
        .stat-card { transition: transform 0.2s, box-shadow 0.2s; min-height: 160px; font-size: 18px; }
        .stat-card:hover { transform: translateY(-6px) scale(1.04); box-shadow: 0 8px 32px rgba(0,0,0,0.12); }
        .stat-card .number { font-size: 48px; font-weight: 900; color: #222; margin-bottom: 12px; }
        .stat-card .label { font-size: 16px; color: #374151; margin-top: 8px; font-weight: 600; }
        .stat-card.yellow { background: linear-gradient(135deg,#fef3c7,#fde68a); border-left: 8px solid #f59e0b; }
        .stat-card.red { background: linear-gradient(135deg,#fee2e2,#fecaca); border-left: 8px solid #ef4444; }
        .stat-card.blue { background: linear-gradient(135deg,#dbeafe,#a5b4fc); border-left: 8px solid #3b82f6; }
        .stat-card.green { background: linear-gradient(135deg,#dcfce7,#bbf7d0); border-left: 8px solid #10b981; }
        .stat-card.yellow .number { color: #f59e0b; }
        .stat-card.red .number { color: #ef4444; }
        .stat-card.blue .number { color: #3b82f6; }
        .stat-card.green .number { color: #10b981; }
        
        /* Table */
        .table-wrap { background: white; border-radius: 14px; box-shadow: 0 2px 12px rgba(0,0,0,0.06); overflow: hidden; }
        .table-header { padding: 20px 24px; border-bottom: 1px solid #f3f4f6; display: flex; justify-content: space-between; align-items: center; }
        .table-header h2 { font-size: 18px; color: #1a1a1a; }
        table { width: 100%; border-collapse: collapse; }
        th { background: #f9fafb; text-align: left; padding: 12px 16px; font-size: 12px; text-transform: uppercase; color: #6B7280; letter-spacing: 0.5px; }
        td { padding: 14px 16px; border-top: 1px solid #f3f4f6; font-size: 14px; }
        tr:hover { background: #f0fdf4; }
        .badge { padding: 4px 10px; border-radius: 20px; font-size: 11px; font-weight: 600; }
        .badge-low { background: #FEF3C7; color: #92400E; }
        .badge-medium { background: #FED7AA; color: #9A3412; }
        .badge-high { background: #FEE2E2; color: #991B1B; }
        .btn-delete { color: #EF4444; text-decoration: none; font-size: 13px; }
        .btn-delete:hover { text-decoration: underline; }
        .map-link { color: #10B981; text-decoration: none; }
        .map-link:hover { text-decoration: underline; }
        
        /* Login */
        .login-wrap { display: flex; justify-content: center; align-items: center; min-height: 100vh; }
        .login-card { background: white; border-radius: 20px; padding: 40px; width: 380px; box-shadow: 0 8px 30px rgba(0,0,0,0.1); text-align: center; }
        .login-card h2 { color: #10B981; font-size: 28px; margin-bottom: 4px; }
        .login-card .sub { color: #6B7280; font-size: 12px; letter-spacing: 3px; margin-bottom: 30px; }
        .login-card input { width: 100%; padding: 12px 16px; border: 1px solid #e5e7eb; border-radius: 10px; margin-bottom: 14px; font-size: 14px; outline: none; }
        .login-card input:focus { border-color: #10B981; box-shadow: 0 0 0 3px rgba(16,185,129,0.1); }
        .login-card button { width: 100%; padding: 14px; background: linear-gradient(135deg, #10B981, #065F46); color: white; border: none; border-radius: 10px; font-size: 16px; font-weight: 600; cursor: pointer; }
        .login-card button:hover { opacity: 0.9; }
        .error { color: #EF4444; font-size: 13px; margin-bottom: 14px; }
        .success { color: #10B981; font-size: 13px; margin-bottom: 14px; }
        
        /* Settings */
        .settings { background: white; border-radius: 14px; padding: 24px; box-shadow: 0 2px 12px rgba(0,0,0,0.06); margin-top: 24px; }
        .settings h3 { margin-bottom: 16px; }
        .settings input { padding: 10px 14px; border: 1px solid #e5e7eb; border-radius: 8px; font-size: 14px; margin-right: 10px; }
        .settings button { padding: 10px 20px; background: #10B981; color: white; border: none; border-radius: 8px; cursor: pointer; font-size: 14px; }
        
        .empty { text-align: center; padding: 60px 20px; color: #6B7280; }
        .empty .icon { font-size: 48px; margin-bottom: 12px; }
        
        @media (max-width: 768px) {
            .stats { grid-template-columns: 1fr 1fr; }
            table { font-size: 12px; }
            td, th { padding: 10px 8px; }
        }
    </style>
</head>
<body>

<?php if (!$isLoggedIn): ?>
<!-- ════════════════ LOGIN PAGE ════════════════ -->
<div class="login-wrap">
    <div class="login-card">
        <h2>🛡️ Seyyon</h2>
        <div class="sub">ADMIN PANEL</div>
        <?php if (isset($loginError)): ?>
            <div class="error"><?= htmlspecialchars($loginError) ?></div>
        <?php endif; ?>
        <form method="POST">
            <input type="text" name="username" placeholder="Username" required>
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit" name="login">Login</button>
        </form>
    </div>
</div>

<?php else: ?>
<!-- ════════════════ DASHBOARD ════════════════ -->
<?php
    $db = getDB();
    
    // Total alerts
    $total = $db->query('SELECT COUNT(*) as c FROM sos_alerts')->fetch()['c'];
    
    // Today's alerts
    $today = $db->query("SELECT COUNT(*) as c FROM sos_alerts WHERE DATE(created_at) = CURDATE()")->fetch()['c'];
    
    // This week
    $week = $db->query("SELECT COUNT(*) as c FROM sos_alerts WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)")->fetch()['c'];
    
    // Unique phones
    $phones = $db->query("SELECT COUNT(DISTINCT phone) as c FROM sos_alerts WHERE phone != ''")->fetch()['c'];
    
    // All alerts
    $alerts = $db->query('SELECT * FROM sos_alerts ORDER BY created_at DESC LIMIT 100')->fetchAll();
?>

<div class="header">
    <div>
        <h1>🛡️ Seyyon Admin</h1>
        <span>THE SAVIOUR</span>
    </div>
    <div style="position:relative;">
        <button id="adminBtn" style="background:rgba(255,255,255,0.2);color:white;border:none;padding:8px 18px;border-radius:8px;font-size:15px;cursor:pointer;display:flex;align-items:center;gap:8px;">
            👤 <?= htmlspecialchars($_SESSION['admin']) ?> <span style="font-size:18px;">▼</span>
        </button>
        <ul id="adminDropdown" style="display:none;position:absolute;right:0;top:40px;background:white;color:#222;box-shadow:0 4px 16px rgba(0,0,0,0.12);border-radius:10px;min-width:180px;z-index:10;list-style:none;padding:0;margin:0;">
            <li style="border-bottom:1px solid #f3f4f6;">
                <a href="#" onclick="showChangePass();return false;" style="display:block;padding:12px 20px;text-decoration:none;color:#222;font-size:15px;">🔑 Change Password</a>
            </li>
            <li>
                <a href="?logout=1" style="display:block;padding:12px 20px;text-decoration:none;color:#EF4444;font-size:15px;">🚪 Logout</a>
            </li>
        </ul>
    </div>
</div>

<div class="container">
    <?php if (isset($passMsg)): ?>
        <div class="success" style="background:#f0fdf4;padding:12px 16px;border-radius:10px;margin-bottom:16px;">✅ <?= $passMsg ?></div>
    <?php endif; ?>
    
    <!-- Stats -->
    <div class="stats">
        <div class="stat-card yellow">
            <div class="number"><?= $total ?></div>
            <div class="label">Total SOS Alerts</div>
        </div>
        <div class="stat-card red">
            <div class="number"><?= $today ?></div>
            <div class="label">Today's Alerts</div>
        </div>
        <div class="stat-card blue">
            <div class="number"><?= $week ?></div>
            <div class="label">This Week</div>
        </div>
        <div class="stat-card green">
            <div class="number"><?= $phones ?></div>
            <div class="label">Unique Users</div>
        </div>
    </div>
    
    <!-- Alerts Table -->
    <div class="table-wrap">
        <div class="table-header">
            <h2>📋 SOS Alert History</h2>
            <span style="color:#6B7280;font-size:13px;">Last 100 alerts</span>
        </div>
        
        <?php if (empty($alerts)): ?>
            <div class="empty">
                <div class="icon">📭</div>
                <p>No SOS alerts yet</p>
                <p style="font-size:13px;margin-top:8px;">Alerts will appear here when users trigger SOS</p>
            </div>
        <?php else: ?>
            <table>
                <thead>
                    <tr>
                        <th>#</th>
                        <th>Date & Time</th>
                        <th>Phone</th>
                        <th>Location</th>
                        <th>Map</th>
                        <th>Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php $sno=1; foreach ($alerts as $alert): ?>
                    <tr>
                        <td><?= $sno++ ?></td>
                        <td><?= date('d M Y, h:i A', strtotime($alert['created_at'])) ?></td>
                        <td><?= htmlspecialchars($alert['phone'] ?: '—') ?></td>
                        <td><?= round($alert['latitude'], 6) ?>, <?= round($alert['longitude'], 6) ?></td>
                        <td>
                            <a class="map-link" href="https://maps.google.com/?q=<?= $alert['latitude'] ?>,<?= $alert['longitude'] ?>" target="_blank">
                                📍 View Map
                            </a>
                        </td>
                        <td>
                            <a class="btn-delete" href="?delete=<?= $alert['id'] ?>" onclick="return confirm('Delete this alert?')">🗑️ Delete</a>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>
    
        <!-- Change Password Modal -->
        <div id="changePassModal" style="display:none;position:fixed;top:0;left:0;width:100vw;height:100vh;background:rgba(0,0,0,0.18);z-index:100;align-items:center;justify-content:center;">
            <div style="background:linear-gradient(135deg,#fef3c7,#fde68a);border-left:8px solid #f59e0b;box-shadow:0 8px 32px rgba(0,0,0,0.18);border-radius:16px;min-width:320px;max-width:90vw;padding:32px 28px 24px 28px;">
                <h3 style="margin-bottom:18px;font-size:20px;color:#f59e0b;">🔑 Change Password</h3>
                <form method="POST" style="display:flex;align-items:center;flex-wrap:wrap;gap:10px;">
                        <input type="password" name="new_password" placeholder="New password" required minlength="6" style="padding:10px 14px;border:1px solid #e5e7eb;border-radius:8px;font-size:14px;width:200px;">
                        <button type="submit" name="change_password" style="padding:10px 20px;background:#10B981;color:white;border:none;border-radius:8px;cursor:pointer;font-size:14px;">Update</button>
                        <button type="button" onclick="hideChangePass();" style="padding:10px 20px;background:#e5e7eb;color:#222;border:none;border-radius:8px;cursor:pointer;font-size:14px;">Cancel</button>
                </form>
            </div>
        </div>
</div>

<?php endif; ?>
<script>
// Admin dropdown
const btn = document.getElementById('adminBtn');
const dd = document.getElementById('adminDropdown');
btn.onclick = function(e) {
    e.stopPropagation();
    dd.style.display = dd.style.display === 'block' ? 'none' : 'block';
};
document.body.onclick = function() { dd.style.display = 'none'; };

// Change password modal
function showChangePass() {
    document.getElementById('changePassModal').style.display = 'flex';
    dd.style.display = 'none';
}
function hideChangePass() {
    document.getElementById('changePassModal').style.display = 'none';
}
</script>
</body>
</html>
