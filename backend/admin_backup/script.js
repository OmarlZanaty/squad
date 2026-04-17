// API Configuration
const API_BASE = '/api/admin';
const ADMIN_KEY = 'another_super_secret_admin_key_for_postman_access';

// Mock Data
let users = [
  {id: 1, name: 'أحمد محمد', email: 'ahmed@example.com', phone: '+20123456789', type: 'player', status: 'active', created_at: '2024-01-15', last_login: '2024-12-26', verified: true},
  {id: 2, name: 'سارة علي', email: 'sara@example.com', phone: '+20123456790', type: 'scout', status: 'active', created_at: '2024-02-20', last_login: '2024-12-25', verified: true},
  {id: 3, name: 'محمد حسن', email: 'mohamed@example.com', phone: '+20123456791', type: 'player', status: 'pending', created_at: '2024-12-20', last_login: null, verified: false},
  {id: 4, name: 'فاطمة خالد', email: 'fatima@example.com', phone: '+20123456792', type: 'guest', status: 'active', created_at: '2024-03-10', last_login: '2024-12-24', verified: true},
  {id: 5, name: 'عمر يوسف', email: 'omar@example.com', phone: '+20123456793', type: 'player', status: 'banned', created_at: '2024-01-05', last_login: '2024-11-15', verified: true},
  {id: 6, name: 'مريم أحمد', email: 'maryam@example.com', phone: '+20123456794', type: 'player', status: 'active', created_at: '2024-04-12', last_login: '2024-12-26', verified: true},
  {id: 7, name: 'خالد محمود', email: 'khaled@example.com', phone: '+20123456795', type: 'scout', status: 'suspended', created_at: '2024-05-18', last_login: '2024-12-10', verified: true},
  {id: 8, name: 'نور الدين', email: 'nour@example.com', phone: '+20123456796', type: 'player', status: 'active', created_at: '2024-06-22', last_login: '2024-12-25', verified: false}
];

let posts = [
  {id: 1, user_id: 1, user_name: 'أحمد محمد', caption: 'تدريب رائع اليوم! 💪⚽', media_url: 'https://via.placeholder.com/150', status: 'active', views: 342, created_at: '2024-12-26'},
  {id: 2, user_id: 2, user_name: 'سارة علي', caption: 'موهبة واعدة', media_url: 'https://via.placeholder.com/150', status: 'active', views: 567, created_at: '2024-12-25'},
  {id: 3, user_id: 3, user_name: 'محمد حسن', caption: 'محتوى مشبوه', media_url: 'https://via.placeholder.com/150', status: 'pending', views: 12, created_at: '2024-12-26'}
];

let comments = [
  {id: 1, user_id: 1, user_name: 'أحمد محمد', post_id: 2, content: 'رائع جداً!', status: 'active', created_at: '2024-12-26'},
  {id: 2, user_id: 4, user_name: 'فاطمة خالد', post_id: 1, content: 'استمر 👏', status: 'active', created_at: '2024-12-26'},
  {id: 3, user_id: 5, user_name: 'عمر يوسف', post_id: 1, content: 'محتوى مسيء', status: 'hidden', created_at: '2024-12-25'}
];

let reports = [
  {id: 1, reporter_id: 1, reporter_name: 'أحمد محمد', target_type: 'user', target_id: 5, reason: 'سلوك غير لائق', status: 'open', created_at: '2024-12-26'},
  {id: 2, reporter_id: 2, reporter_name: 'سارة علي', target_type: 'post', target_id: 3, reason: 'محتوى مخالف', status: 'open', created_at: '2024-12-25'}
];

let auditLogs = [
  {id: 1, admin_id: 1, admin_name: 'أحمد (Super Admin)', action: 'تعديل مستخدم', target_type: 'user', target_id: 3, metadata: {status: 'active'}, created_at: '2024-12-26 15:30'},
  {id: 2, admin_id: 1, admin_name: 'أحمد (Super Admin)', action: 'حذف منشور', target_type: 'post', target_id: 15, metadata: {reason: 'محتوى مخالف'}, created_at: '2024-12-26 14:15'},
  {id: 3, admin_id: 1, admin_name: 'أحمد (Super Admin)', action: 'حظر مستخدم', target_type: 'user', target_id: 5, metadata: {reason: 'انتهاك متكرر'}, created_at: '2024-12-26 13:00'}
];

// State
let selectedUserId = null;
let selectedUsers = new Set();
let currentPage = 1;
let itemsPerPage = 10;
let currentView = 'users';
let pendingAction = null;
let filteredUsers = [...users];

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
  init();
});

function init() {
  renderUsers();
  renderPosts();
  renderComments();
  renderReports();
  renderAuditLogs();
  updateAllStats();
  setupSearch();
}

// View Switching
function switchView(view, event) {
  if (event) event.preventDefault();
  currentView = view;
  const views = ['users', 'posts', 'comments', 'chats', 'reports', 'analytics', 'audit', 'database'];
  views.forEach(v => {
    const el = document.getElementById(v + 'View');
    if (el) el.style.display = v === view ? 'block' : 'none';
  });
  
  document.querySelectorAll('.sidebar nav a').forEach(a => a.classList.remove('active'));
  if (event) event.target.classList.add('active');
}

// Users Management
function renderUsers() {
  const tbody = document.getElementById('usersTableBody');
  if (!tbody) return;
  
  if (!filteredUsers || filteredUsers.length === 0) {
    tbody.innerHTML = '<tr><td colspan="8" class="empty-state"><div class="empty-state-icon">👥</div><div>لا يوجد مستخدمون</div></td></tr>';
    return;
  }

  tbody.innerHTML = filteredUsers.map(u => `
    <tr class="${selectedUsers.has(u.id) ? 'selected' : ''}">
      <td><input type="checkbox" class="checkbox" data-id="${u.id}" ${selectedUsers.has(u.id) ? 'checked' : ''} onchange="toggleUserSelection(${u.id})"/></td>
      <td>
        <div class="user-cell">
          <div class="avatar">${u.name[0]}</div>
          <div><strong>${u.name}</strong>${u.verified ? ' ✓' : ''}</div>
        </div>
      </td>
      <td>${u.email}</td>
      <td>${getTypeLabel(u.type)}</td>
      <td><span class="badge badge-${u.status}">${getStatusLabel(u.status)}</span></td>
      <td>${formatDate(u.created_at)}</td>
      <td>${u.last_login ? formatDate(u.last_login) : '<span style="color: #94a3b8;">لم يدخل بعد</span>'}</td>
      <td>
        <div class="action-icons">
          <span class="action-icon" onclick="viewUser(${u.id})" title="عرض">👁️</span>
          <span class="action-icon" onclick="editUser(${u.id})" title="تعديل">✏️</span>
          <span class="action-icon" onclick="confirmDelete(${u.id}, 'user')" title="حذف">🗑️</span>
        </div>
      </td>
    </tr>
  `).join('');

  updatePagination();
  updateBulkButtons();
}

function renderPosts() {
  const tbody = document.getElementById('postsTableBody');
  if (!tbody) return;
  
  if (!posts || posts.length === 0) {
    tbody.innerHTML = '<tr><td colspan="8" class="empty-state"><div class="empty-state-icon">📝</div><div>لا توجد منشورات</div></td></tr>';
    return;
  }

  tbody.innerHTML = posts.map(p => `
    <tr>
      <td><input type="checkbox" class="checkbox"/></td>
      <td><img src="${p.media_url}" class="media-preview" alt="منشور" onclick="viewMedia('${p.media_url}')"/></td>
      <td>${p.user_name}</td>
      <td>${p.caption.substring(0, 40)}${p.caption.length > 40 ? '...' : ''}</td>
      <td><span class="badge badge-${p.status}">${getStatusLabel(p.status)}</span></td>
      <td>${p.views.toLocaleString()}</td>
      <td>${formatDate(p.created_at)}</td>
      <td>
        <div class="action-icons">
          <span class="action-icon" onclick="approvePost(${p.id})" title="موافقة">✓</span>
          <span class="action-icon" onclick="hidePost(${p.id})" title="إخفاء">👁️</span>
          <span class="action-icon" onclick="deletePost(${p.id})" title="حذف">🗑️</span>
        </div>
      </td>
    </tr>
  `).join('');
}

function renderComments() {
  const tbody = document.getElementById('commentsTableBody');
  if (!tbody) return;
  
  if (!comments || comments.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" class="empty-state"><div class="empty-state-icon">💬</div><div>لا توجد تعليقات</div></td></tr>';
    return;
  }

  tbody.innerHTML = comments.map(c => `
    <tr>
      <td><input type="checkbox" class="checkbox"/></td>
      <td>${c.user_name}</td>
      <td>${c.content}</td>
      <td>منشور #${c.post_id}</td>
      <td><span class="badge badge-${c.status}">${getStatusLabel(c.status)}</span></td>
      <td>${formatDate(c.created_at)}</td>
      <td>
        <div class="action-icons">
          <span class="action-icon" onclick="showComment(${c.id})" title="إظهار">✓</span>
          <span class="action-icon" onclick="hideComment(${c.id})" title="إخفاء">👁️</span>
          <span class="action-icon" onclick="deleteComment(${c.id})" title="حذف">🗑️</span>
        </div>
      </td>
    </tr>
  `).join('');
}

function renderReports() {
  const tbody = document.getElementById('reportsTableBody');
  if (!tbody) return;
  
  if (!reports || reports.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" class="empty-state"><div class="empty-state-icon">🚨</div><div>لا توجد بلاغات</div></td></tr>';
    return;
  }

  tbody.innerHTML = reports.map(r => `
    <tr>
      <td>${r.reporter_name}</td>
      <td>${r.target_type === 'user' ? 'مستخدم' : r.target_type === 'post' ? 'منشور' : 'تعليق'}</td>
      <td>${r.target_type} #${r.target_id}</td>
      <td>${r.reason}</td>
      <td><span class="badge badge-${r.status}">${r.status === 'open' ? 'مفتوح' : r.status === 'reviewed' ? 'قيد المراجعة' : 'محلول'}</span></td>
      <td>${formatDate(r.created_at)}</td>
      <td>
        <div class="action-icons">
          <span class="action-icon" onclick="reviewReport(${r.id})" title="مراجعة">👁️</span>
          <span class="action-icon" onclick="resolveReport(${r.id})" title="حل">✓</span>
        </div>
      </td>
    </tr>
  `).join('');
}

function renderAuditLogs() {
  const tbody = document.getElementById('auditTableBody');
  if (!tbody) return;
  
  if (!auditLogs || auditLogs.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" class="empty-state"><div class="empty-state-icon">📜</div><div>لا توجد عمليات مسجلة</div></td></tr>';
    return;
  }

  tbody.innerHTML = auditLogs.map(log => `
    <tr>
      <td>${log.admin_name}</td>
      <td><strong>${log.action}</strong></td>
      <td>${log.target_type}</td>
      <td>#${log.target_id}</td>
      <td style="font-size: 12px; color: #64748b;">${JSON.stringify(log.metadata)}</td>
      <td>${log.created_at}</td>
    </tr>
  `).join('');
}

// User Actions
function viewUser(id) {
  const user = users.find(u => u.id === id);
  if (!user) return;
  
  selectedUserId = id;
  document.getElementById('viewUserName').textContent = user.name;
  document.getElementById('viewUserEmail').textContent = user.email;
  document.getElementById('viewUserAvatar').textContent = user.name[0];
  document.getElementById('viewUserType').textContent = getTypeLabel(user.type);
  document.getElementById('viewUserStatus').innerHTML = `<span class="badge badge-${user.status}">${getStatusLabel(user.status)}</span>`;
  document.getElementById('viewUserJoined').textContent = formatDate(user.created_at);
  
  openModal('viewUserModal');
}

function editUser(id) {
  selectedUserId = id;
  const user = users.find(u => u.id === id);
  if (!user) return;
  
  document.getElementById('editName').value = user.name;
  document.getElementById('editEmail').value = user.email;
  document.getElementById('editPhone').value = user.phone;
  document.getElementById('editType').value = user.type;
  document.getElementById('editStatus').value = user.status;
  document.getElementById('editNotes').value = '';
  
  openModal('editUserModal');
}

function editUserFromView() {
  closeModal('viewUserModal');
  editUser(selectedUserId);
}

function saveUser() {
  if (!selectedUserId) return;
  
  const user = users.find(u => u.id === selectedUserId);
  if (!user) return;
  
  const oldStatus = user.status;
  user.name = document.getElementById('editName').value;
  user.phone = document.getElementById('editPhone').value;
  user.type = document.getElementById('editType').value;
  user.status = document.getElementById('editStatus').value;
  
  // Log audit
  logAudit('تعديل مستخدم', 'user', selectedUserId, {
    old_status: oldStatus,
    new_status: user.status,
    notes: document.getElementById('editNotes').value
  });
  
  closeModal('editUserModal');
  renderUsers();
  updateAllStats();
  showToast('تم حفظ التغييرات بنجاح', 'success');
}

function confirmDelete(id, type) {
  pendingAction = { action: 'delete', type, id };
  document.getElementById('confirmIcon').textContent = '🗑️';
  document.getElementById('confirmMessage').textContent = 'هل أنت متأكد من الحذف؟';
  document.getElementById('confirmDetails').textContent = 'هذا الإجراء لا يمكن التراجع عنه';
  openModal('confirmModal');
}

function confirmAction() {
  if (!pendingAction) return;
  
  const { action, type, id } = pendingAction;
  
  if (action === 'delete' && type === 'user') {
    const user = users.find(u => u.id === id);
    users = users.filter(u => u.id !== id);
    filteredUsers = filteredUsers.filter(u => u.id !== id);
    logAudit('حذف مستخدم', 'user', id, { name: user.name });
    renderUsers();
    updateAllStats();
    showToast('تم حذف المستخدم بنجاح', 'success');
  }
  
  closeModal('confirmModal');
  pendingAction = null;
}

// Bulk Actions
function toggleUserSelection(id) {
  if (selectedUsers.has(id)) {
    selectedUsers.delete(id);
  } else {
    selectedUsers.add(id);
  }
  renderUsers();
}

function selectAll(checkbox) {
  if (checkbox.checked) {
    filteredUsers.forEach(u => selectedUsers.add(u.id));
  } else {
    selectedUsers.clear();
  }
  renderUsers();
}

function updateBulkButtons() {
  const count = selectedUsers.size;
  document.getElementById('selectedCount').textContent = count;
  
  const buttons = ['bulkActivateBtn', 'bulkSuspendBtn', 'bulkBanBtn'];
  buttons.forEach(btnId => {
    const btn = document.getElementById(btnId);
    if (btn) btn.disabled = count === 0;
  });
}

function bulkActivate() {
  if (selectedUsers.size === 0) return;
  selectedUsers.forEach(id => {
    const user = users.find(u => u.id === id);
    if (user) {
      user.status = 'active';
      logAudit('تفعيل مستخدم (إجراء جماعي)', 'user', id, {});
    }
  });
  selectedUsers.clear();
  renderUsers();
  updateAllStats();
  showToast('تم تفعيل المستخدمين المحددين', 'success');
}

function bulkSuspend() {
  if (selectedUsers.size === 0) return;
  selectedUsers.forEach(id => {
    const user = users.find(u => u.id === id);
    if (user) {
      user.status = 'suspended';
      logAudit('إيقاف مستخدم (إجراء جماعي)', 'user', id, {});
    }
  });
  selectedUsers.clear();
  renderUsers();
  updateAllStats();
  showToast('تم إيقاف المستخدمين المحددين', 'warning');
}

function bulkBan() {
  if (selectedUsers.size === 0) return;
  selectedUsers.forEach(id => {
    const user = users.find(u => u.id === id);
    if (user) {
      user.status = 'banned';
      logAudit('حظر مستخدم (إجراء جماعي)', 'user', id, {});
    }
  });
  selectedUsers.clear();
  renderUsers();
  updateAllStats();
  showToast('تم حظر المستخدمين المحددين', 'error');
}

// Post Actions
function approvePost(id) {
  const post = posts.find(p => p.id === id);
  if (post) {
    post.status = 'active';
    logAudit('الموافقة على منشور', 'post', id, {});
    renderPosts();
    showToast('تمت الموافقة على المنشور', 'success');
  }
}

function hidePost(id) {
  const post = posts.find(p => p.id === id);
  if (post) {
    post.status = 'hidden';
    logAudit('إخفاء منشور', 'post', id, {});
    renderPosts();
    showToast('تم إخفاء المنشور', 'warning');
  }
}

function deletePost(id) {
  posts = posts.filter(p => p.id !== id);
  logAudit('حذف منشور', 'post', id, {});
  renderPosts();
  showToast('تم حذف المنشور', 'success');
}

// Comment Actions
function showComment(id) {
  const comment = comments.find(c => c.id === id);
  if (comment) {
    comment.status = 'active';
    renderComments();
    showToast('تم إظهار التعليق', 'success');
  }
}

function hideComment(id) {
  const comment = comments.find(c => c.id === id);
  if (comment) {
    comment.status = 'hidden';
    renderComments();
    showToast('تم إخفاء التعليق', 'warning');
  }
}

function deleteComment(id) {
  comments = comments.filter(c => c.id !== id);
  renderComments();
  showToast('تم حذف التعليق', 'success');
}

// Report Actions
function reviewReport(id) {
  const report = reports.find(r => r.id === id);
  if (report) {
    report.status = 'reviewed';
    renderReports();
    showToast('تم وضع البلاغ قيد المراجعة', 'success');
  }
}

function resolveReport(id) {
  const report = reports.find(r => r.id === id);
  if (report) {
    report.status = 'resolved';
    renderReports();
    showToast('تم حل البلاغ', 'success');
  }
}

// Filters
function toggleFilters(panelId) {
  const panel = document.getElementById(panelId);
  if (panel) {
    panel.classList.toggle('show');
  }
}

function applyFilters() {
  const status = document.getElementById('filterStatus').value;
  const type = document.getElementById('filterType').value;
  const date = document.getElementById('filterDate').value;
  
  filteredUsers = users.filter(u => {
    if (status && u.status !== status) return false;
    if (type && u.type !== type) return false;
    // Date filtering would go here
    return true;
  });
  
  renderUsers();
}

function clearFilters() {
  document.getElementById('filterStatus').value = '';
  document.getElementById('filterType').value = '';
  document.getElementById('filterDate').value = '';
  filteredUsers = [...users];
  renderUsers();
}

// Search
function setupSearch() {
  const searchInput = document.getElementById('userSearch');
  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      const query = e.target.value.toLowerCase();
      filteredUsers = users.filter(u => 
        u.name.toLowerCase().includes(query) || 
        u.email.toLowerCase().includes(query)
      );
      renderUsers();
    });
  }
}

// Export Data
function exportData(type) {
  let data, filename;
  
  if (type === 'users') {
    data = users;
    filename = 'users_export.json';
  } else if (type === 'audit') {
    data = auditLogs;
    filename = 'audit_logs.json';
  }
  
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
  
  showToast(`تم تصدير البيانات: ${filename}`, 'success');
}

// Pagination
function updatePagination() {
  const total = filteredUsers.length;
  const start = (currentPage - 1) * itemsPerPage + 1;
  const end = Math.min(start + itemsPerPage - 1, total);
  
  document.getElementById('pageStart').textContent = start;
  document.getElementById('pageEnd').textContent = end;
  document.getElementById('pageTotal').textContent = total;
}

function prevPage() {
  if (currentPage > 1) {
    currentPage--;
    renderUsers();
  }
}

function nextPage() {
  const maxPage = Math.ceil(filteredUsers.length / itemsPerPage);
  if (currentPage < maxPage) {
    currentPage++;
    renderUsers();
  }
}

// Audit Logging
function logAudit(action, targetType, targetId, metadata) {
  const log = {
    id: auditLogs.length + 1,
    admin_id: 1,
    admin_name: 'أحمد (Super Admin)',
    action,
    target_type: targetType,
    target_id: targetId,
    metadata,
    created_at: new Date().toLocaleString('ar-EG')
  };
  auditLogs.unshift(log);
  renderAuditLogs();
}

// Modal Management
function openModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) modal.classList.add('show');
}

function closeModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) modal.classList.remove('show');
}

// Toast Notifications
function showToast(message, type = 'success') {
  const toast = document.getElementById('toast');
  toast.textContent = message;
  toast.className = 'toast show ' + type;
  setTimeout(() => {
    toast.classList.remove('show');
  }, 3000);
}

// Stats Update
function updateAllStats() {
  document.getElementById('totalUsers').textContent = users.length;
  document.getElementById('activeUsers').textContent = users.filter(u => u.status === 'active').length;
  document.getElementById('pendingUsers').textContent = users.filter(u => u.status === 'pending').length;
  document.getElementById('bannedUsers').textContent = users.filter(u => u.status === 'banned').length;
}

// Utility Functions
function getTypeLabel(type) {
  const types = {
    player: 'لاعب',
    scout: 'كشاف',
    guest: 'زائر'
  };
  return types[type] || type;
}

function getStatusLabel(status) {
  const statuses = {
    active: 'نشط',
    pending: 'قيد المراجعة',
    suspended: 'موقوف',
    banned: 'محظور',
    hidden: 'مخفي',
    open: 'مفتوح',
    resolved: 'محلول'
  };
  return statuses[status] || status;
}

function formatDate(dateStr) {
  if (!dateStr) return '-';
  const date = new Date(dateStr);
  return date.toLocaleDateString('ar-EG', { year: 'numeric', month: 'short', day: 'numeric' });
}

function viewMedia(url) {
  window.open(url, '_blank');
}

// API Integration (replace mock data with real API calls)
/*
async function loadUsers() {
  try {
    const response = await fetch(`${API_BASE}/users`, {
      headers: { 'x-admin-key': ADMIN_KEY }
    });
    const data = await response.json();
    users = data.data || [];
    filteredUsers = [...users];
    renderUsers();
    updateAllStats();
  } catch (error) {
    console.error('Error loading users:', error);
    showToast('فشل تحميل المستخدمين', 'error');
  }
}

async function updateUser(id, updates) {
  try {
    await fetch(`${API_BASE}/users/${id}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'x-admin-key': ADMIN_KEY
      },
      body: JSON.stringify(updates)
    });
  } catch (error) {
    console.error('Error updating user:', error);
    showToast('فشل التحديث', 'error');
  }
}
*/