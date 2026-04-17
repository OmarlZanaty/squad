// Squad Admin Dashboard - Enhanced JavaScript
// API Configuration
const API_URL = 'http://localhost:3000/api/admin/dashboard';

// Pagination Configuration
const PAGE_SIZE = 20;
let currentPages = {
    users: 1,
    approvals: 1,
    posts: 1,
    chats: 1,
    logs: 1
};

// Data Storage
let allData = {
    users: [],
    approvals: [],
    posts: [],
    chats: [],
    logs: []
};

// Selected Items for Bulk Actions
let selectedItems = {
    users: new Set(),
    approvals: new Set(),
    posts: new Set()
};

// ============================================
// INITIALIZATION
// ============================================

document.addEventListener('DOMContentLoaded', function() {
    loadStats();
    loadUsers();
    loadAnalytics();
    
    // Setup notification type change handler
    document.getElementById('notification-type').addEventListener('change', function() {
        const specificUserGroup = document.getElementById('specific-user-group');
        specificUserGroup.style.display = this.value === 'specific' ? 'block' : 'none';
    });
});

// ============================================
// TAB SWITCHING
// ============================================

function switchTab(tabName) {
    // Hide all tabs
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.remove('active');
    });
    
    // Remove active class from all buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    
    // Show selected tab
    document.getElementById(tabName + '-tab').classList.add('active');
    event.target.classList.add('active');
    
    // Load data for the tab if not loaded
    switch(tabName) {
        case 'users':
            if (allData.users.length === 0) loadUsers();
            break;
        case 'approvals':
            if (allData.approvals.length === 0) loadApprovals();
            break;
        case 'posts':
            if (allData.posts.length === 0) loadPosts();
            break;
        case 'chats':
            if (allData.chats.length === 0) loadChats();
            break;
        case 'analytics':
            loadAnalytics();
            break;
        case 'reports':
            loadReports();
            break;
        case 'logs':
            if (allData.logs.length === 0) loadLogs();
            break;
    }
}

// ============================================
// TOAST NOTIFICATIONS
// ============================================

function showToast(message, type = 'info') {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.className = `toast toast-${type} show`;
    
    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
}

// ============================================
// STATISTICS
// ============================================

async function loadStats() {
    try {
        const response = await fetch(`${API_URL}/stats`);
        const data = await response.json();
        
        document.getElementById('total-users').textContent = data.totalUsers || 0;
        document.getElementById('pending-approvals').textContent = data.pendingApprovals || 0;
        document.getElementById('total-posts').textContent = data.totalPosts || 0;
        document.getElementById('total-chats').textContent = data.totalChats || 0;
        
        // Calculate growth (mock data for now)
        document.getElementById('users-change').textContent = '+12%';
        document.getElementById('posts-change').textContent = '+8%';
        
    } catch (error) {
        console.error('Error loading stats:', error);
    }
}

// ============================================
// USERS MANAGEMENT
// ============================================

async function loadUsers() {
    try {
        const response = await fetch(`${API_URL}/users`);
        const data = await response.json();
        allData.users = data.users || [];
        renderUsers();
        console.log(data.users);
        logActivity('system', 'view', 'تم عرض قائمة المستخدمين');
    } catch (error) {
        console.error('Error loading users:', error);
        document.getElementById('users-tbody').innerHTML = `
            <tr><td colspan="8" class="error">
                <i class="fas fa-exclamation-circle"></i>
                <p>خطأ في تحميل البيانات</p>
            </td></tr>
        `;
    }
}

function renderUsers(filteredData = null) {
    const users = filteredData || allData.users;
    const tbody = document.getElementById('users-tbody');
    
    if (users.length === 0) {
        tbody.innerHTML = `
            <tr><td colspan="8" class="empty-state">
                <i class="fas fa-users"></i>
                <p>لا يوجد مستخدمون</p>
            </td></tr>
        `;
        return;
    }
    
    const start = (currentPages.users - 1) * PAGE_SIZE;
    const end = start + PAGE_SIZE;
    const paginatedUsers = users.slice(start, end);
    
    tbody.innerHTML = paginatedUsers.map((user, index) => `
        <tr>
            <td><input type="checkbox" class="user-checkbox" data-id="${user.id}" onchange="toggleUserSelection(${user.id})"></td>
            <td>${start + index + 1}</td>
            <td>
                <div class="user-info">
                    <i class="fas fa-user-circle"></i>
                    <span>${user.name}</span>
                </div>
            </td>
            <td>${user.email}</td>
            <td><span class="badge badge-info">${translatePosition(user.position)}</span></td>
            <td><span class="badge badge-${getStatusColor(user.status)}">${translateStatus(user.status)}</span></td>
            <td>${formatDate(user.created_at)}</td>
            <td>
                <div class="action-buttons">
                    <button class="btn btn-sm btn-info" onclick="editUser(${user.id})" title="تعديل">
                        <i class="fas fa-edit"></i>
                    </button>
                    <button class="btn btn-sm btn-warning" onclick="viewUserDetails(${user.id})" title="عرض التفاصيل">
                        <i class="fas fa-eye"></i>
                    </button>
                    <button class="btn btn-sm btn-danger" onclick="deleteUser(${user.id})" title="حذف">
                        <i class="fas fa-trash"></i>
                    </button>
                </div>
            </td>
        </tr>
    `).join('');
    
    renderPagination('users', users.length);
}

function filterUsers() {
    const searchTerm = document.getElementById('users-search').value.toLowerCase();
    const statusFilter = document.getElementById('users-status-filter').value;
    const positionFilter = document.getElementById('users-position-filter').value;
    
        let filtered = allData.users.filter(user => {
        const matchesSearch =
            (user.name && user.name.toLowerCase().includes(searchTerm)) ||
            (user.email && user.email.toLowerCase().includes(searchTerm)) ||
            (user.phone && user.phone.toLowerCase().includes(searchTerm)); // ✅ NEW

        return matchesSearch;
    });
    
    currentPages.users = 1;
    renderUsers(filtered);
}

function editUser(id) {
    const user = allData.users.find(u => u.id === id);
    if (!user) return;
    
    document.getElementById('edit-user-id').value = user.id;
    document.getElementById('edit-user-name').value = user.name;
    document.getElementById('edit-user-email').value = user.email;
    document.getElementById('edit-user-position').value = user.position;
    document.getElementById('edit-user-status').value = user.status;
    
    document.getElementById('edit-user-modal').style.display = 'flex';
}

async function saveUserEdit() {
    const id = document.getElementById('edit-user-id').value;
    const name = document.getElementById('edit-user-name').value;
    const email = document.getElementById('edit-user-email').value;
    const position = document.getElementById('edit-user-position').value;
    const status = document.getElementById('edit-user-status').value;
    
    try {
        const response = await fetch(`${API_URL}/users/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, email, position, status })
        });
        
        if (response.ok) {
            showToast('تم تحديث بيانات المستخدم بنجاح', 'success');
            closeModal('edit-user-modal');
            loadUsers();
            logActivity('user', 'update', `تم تحديث بيانات المستخدم #${id}`);
        } else {
            throw new Error('Failed to update user');
        }
    } catch (error) {
        showToast('خطأ في تحديث البيانات', 'error');
    }
}

async function deleteUser(id) {
    if (!confirm('هل أنت متأكد من حذف هذا المستخدم؟')) return;
    
    try {
        const response = await fetch(`${API_URL}/users/${id}`, {
            method: 'DELETE'
        });
        
        if (response.ok) {
            showToast('تم حذف المستخدم بنجاح', 'success');
            loadUsers();
            loadStats();
            logActivity('user', 'delete', `تم حذف المستخدم #${id}`);
        } else {
            throw new Error('Failed to delete user');
        }
    } catch (error) {
        showToast('خطأ في حذف المستخدم', 'error');
    }
}

async function viewUserDetails(id) {
    try {
        const response = await fetch(`${API_URL}/users/${id}`);
        
        if (!response.ok) {
            if (response.status === 404) {
                showToast('المستخدم غير موجود', 'error');
            } else {
                showToast(`خطأ في الخادم: ${response.status}`, 'error');
            }
            return;
        }
        
        const data = await response.json();
        
        if (!data.user) {
            showToast('خطأ في تحميل بيانات المستخدم', 'error');
            return;
        }
        
        const user = data.user;
        
        // Set profile image
        const profileImage = document.getElementById('view-user-image');
        if (user.profile_image) {
            profileImage.src = `http://localhost:3000${user.profile_image}`;
        } else {
            profileImage.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="80" height="80"%3E%3Crect fill="%23667eea" width="80" height="80"/%3E%3Ctext x="50%25" y="50%25" font-size="32" fill="white" text-anchor="middle" dy=".3em"%3E' + (user.name ? user.name.charAt(0).toUpperCase() : 'U') + '%3C/text%3E%3C/svg%3E';
        }
        
        // Set basic info
        document.getElementById('view-user-name').textContent = user.name || '-';
        document.getElementById('view-user-email').textContent = user.email || '-';
        document.getElementById('view-user-id').textContent = user.id || '-';
        document.getElementById('view-user-position').textContent = translatePosition(user.position) || '-';
        document.getElementById('view-user-phone').textContent = user.phone || '-';
        document.getElementById('view-user-status').innerHTML = `<span class="badge badge-${getStatusColor(user.status)}">${translateStatus(user.status)}</span>`;
        
        // Set statistics
        document.getElementById('view-user-posts').textContent = user.posts_count || 0;
        document.getElementById('view-user-chats').textContent = user.chats_count || 0;
        document.getElementById('view-user-created').textContent = formatDate(user.created_at);
        
        // Set bio
        document.getElementById('view-user-bio').textContent = user.bio || 'لا توجد نبذة شخصية';
        
        // Store current user ID for edit function
        window.currentViewUserId = user.id;
        
        // Show modal
        document.getElementById('view-user-modal').style.display = 'flex';
        
    } catch (error) {
        console.error('Error viewing user details:', error);
        showToast('خطأ في تحميل تفاصيل المستخدم', 'error');
    }
}

function editUserFromDetails() {
    if (window.currentViewUserId) {
        closeModal('view-user-modal');
        editUser(window.currentViewUserId);
    }
}

// ============================================
// APPROVALS MANAGEMENT
// ============================================

async function loadApprovals() {
    try {
        const response = await fetch(`${API_URL}/approvals`);
        const data = await response.json();
        allData.approvals = data.users || [];
        renderApprovals();
    } catch (error) {
        console.error('Error loading approvals:', error);
    }
}

function renderApprovals(filteredData = null) {
    const approvals = filteredData || allData.approvals;
    const tbody = document.getElementById('approvals-tbody');
    
    if (approvals.length === 0) {
        tbody.innerHTML = `
            <tr><td colspan="7" class="empty-state">
                <i class="fas fa-check-circle"></i>
                <p>لا توجد طلبات موافقة</p>
            </td></tr>
        `;
        return;
    }
    
    const start = (currentPages.approvals - 1) * PAGE_SIZE;
    const end = start + PAGE_SIZE;
    const paginatedApprovals = approvals.slice(start, end);
    
    tbody.innerHTML = paginatedApprovals.map((user, index) => `
        <tr>
            <td><input type="checkbox" class="approval-checkbox" data-id="${user.id}" onchange="toggleApprovalSelection(${user.id})"></td>
            <td>${start + index + 1}</td>
            <td>${user.name}</td>
            <td>${user.email}</td>
            <td><span class="badge badge-info">${translatePosition(user.position)}</span></td>
            <td>${formatDate(user.created_at)}</td>
            <td>
                <div class="action-buttons">
                    <button class="btn btn-sm btn-success" onclick="approveUser(${user.id})">
                        <i class="fas fa-check"></i> موافقة
                    </button>
                    <button class="btn btn-sm btn-danger" onclick="rejectUser(${user.id})">
                        <i class="fas fa-times"></i> رفض
                    </button>
                </div>
            </td>
        </tr>
    `).join('');
    
    renderPagination('approvals', approvals.length);
}

function filterApprovals() {
    const searchTerm = document.getElementById('approvals-search').value.toLowerCase();
    
    let filtered = allData.approvals.filter(user => {
        return user.name.toLowerCase().includes(searchTerm) || 
               user.email.toLowerCase().includes(searchTerm);
    });
    
    currentPages.approvals = 1;
    renderApprovals(filtered);
}

async function approveUser(id) {
    try {
        const response = await fetch(`${API_URL}/approvals/${id}/approve`, {
            method: 'POST'
        });
        
        if (response.ok) {
            showToast('تمت الموافقة على المستخدم', 'success');
            loadApprovals();
            loadStats();
            logActivity('user', 'approve', `تمت الموافقة على المستخدم #${id}`);
        } else {
            throw new Error('Failed to approve user');
        }
    } catch (error) {
        showToast('خطأ في الموافقة', 'error');
    }
}

async function rejectUser(id) {
    if (!confirm('هل أنت متأكد من رفض هذا المستخدم؟')) return;
    
    try {
        const response = await fetch(`${API_URL}/approvals/${id}/reject`, {
            method: 'POST'
        });
        
        if (response.ok) {
            showToast('تم رفض المستخدم', 'success');
            loadApprovals();
            loadStats();
            logActivity('user', 'reject', `تم رفض المستخدم #${id}`);
        } else {
            throw new Error('Failed to reject user');
        }
    } catch (error) {
        showToast('خطأ في الرفض', 'error');
    }
}

// ============================================
// POSTS MANAGEMENT
// ============================================

async function loadPosts() {
    try {
        const response = await fetch(`${API_URL}/posts`);
        const data = await response.json();
        allData.posts = data.posts || [];
        renderPosts();
    } catch (error) {
        console.error('Error loading posts:', error);
    }
}

function renderPosts(filteredData = null) {
    const posts = filteredData || allData.posts;
    const tbody = document.getElementById('posts-tbody');
    
    if (posts.length === 0) {
        tbody.innerHTML = `
            <tr><td colspan="8" class="empty-state">
                <i class="fas fa-file-alt"></i>
                <p>لا توجد منشورات</p>
            </td></tr>
        `;
        return;
    }
    
    const start = (currentPages.posts - 1) * PAGE_SIZE;
    const end = start + PAGE_SIZE;
    const paginatedPosts = posts.slice(start, end);
    
    tbody.innerHTML = paginatedPosts.map((post, index) => `
        <tr>
            <td><input type="checkbox" class="post-checkbox" data-id="${post.id}" onchange="togglePostSelection(${post.id})"></td>
            <td>${start + index + 1}</td>
            <td>${post.author_name || 'Unknown'}</td>
            <td class="post-caption">${truncateText(post.caption, 50)}</td>
            <td><span class="badge badge-${getMediaBadge(post.media_type)}">${translateMediaType(post.media_type)}</span></td>
            <td>
                <div class="engagement-stats">
                    <span><i class="fas fa-heart"></i> ${post.likes_count || 0}</span>
                    <span><i class="fas fa-comment"></i> ${post.comments_count || 0}</span>
                </div>
            </td>
            <td>${formatDate(post.created_at)}</td>
            <td>
                <div class="action-buttons">
                    <button class="btn btn-sm btn-info" onclick="editPost(${post.id})" title="تعديل">
                        <i class="fas fa-edit"></i>
                    </button>
                    <button class="btn btn-sm btn-warning" onclick="viewPost(${post.id})" title="عرض">
                        <i class="fas fa-eye"></i>
                    </button>
                    <button class="btn btn-sm btn-danger" onclick="deletePost(${post.id})" title="حذف">
                        <i class="fas fa-trash"></i>
                    </button>
                </div>
            </td>
        </tr>
    `).join('');
    
    renderPagination('posts', posts.length);
}

function filterPosts() {
    const searchTerm = document.getElementById('posts-search').value.toLowerCase();
    const mediaFilter = document.getElementById('posts-media-filter').value;
    const dateFilter = document.getElementById('posts-date-filter').value;
    
    let filtered = allData.posts.filter(post => {
        const matchesSearch = post.caption.toLowerCase().includes(searchTerm) || 
                            (post.author_name && post.author_name.toLowerCase().includes(searchTerm));
        const matchesMedia = !mediaFilter || post.media_type === mediaFilter;
        const matchesDate = !dateFilter || post.created_at.startsWith(dateFilter);
        
        return matchesSearch && matchesMedia && matchesDate;
    });
    
    currentPages.posts = 1;
    renderPosts(filtered);
}

function editPost(id) {
    const post = allData.posts.find(p => p.id === id);
    if (!post) return;
    
    document.getElementById('edit-post-id').value = post.id;
    document.getElementById('edit-post-caption').value = post.caption;
    document.getElementById('edit-post-status').value = post.status || 'visible';
    
    document.getElementById('edit-post-modal').style.display = 'flex';
}

async function savePostEdit() {
    const id = document.getElementById('edit-post-id').value;
    const caption = document.getElementById('edit-post-caption').value;
    const status = document.getElementById('edit-post-status').value;
    
    try {
        const response = await fetch(`${API_URL}/posts/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ caption, status })
        });
        
        if (response.ok) {
            showToast('تم تحديث المنشور بنجاح', 'success');
            closeModal('edit-post-modal');
            loadPosts();
            logActivity('post', 'update', `تم تحديث المنشور #${id}`);
        } else {
            throw new Error('Failed to update post');
        }
    } catch (error) {
        showToast('خطأ في تحديث المنشور', 'error');
    }
}

async function deletePost(id) {
    if (!confirm('هل أنت متأكد من حذف هذا المنشور؟')) return;
    
    try {
        const response = await fetch(`${API_URL}/posts/${id}`, {
            method: 'DELETE'
        });
        
        if (response.ok) {
            showToast('تم حذف المنشور بنجاح', 'success');
            loadPosts();
            loadStats();
            logActivity('post', 'delete', `تم حذف المنشور #${id}`);
        } else {
            throw new Error('Failed to delete post');
        }
    } catch (error) {
        showToast('خطأ في حذف المنشور', 'error');
    }
}

function viewPost(id) {
    const post = allData.posts.find(p => p.id === id);
    if (!post) return;
    
    showToast(`عرض المنشور #${id}`, 'info');
    // TODO: Implement detailed post view modal
}

// ============================================
// CHATS MANAGEMENT
// ============================================

async function loadChats() {
    try {
        const response = await fetch(`${API_URL}/chats`);
        const data = await response.json();
        allData.chats = data.chats || [];
        renderChats();
    } catch (error) {
        console.error('Error loading chats:', error);
    }
}

function renderChats(filteredData = null) {
    const chats = filteredData || allData.chats;
    const tbody = document.getElementById('chats-tbody');
    
    if (chats.length === 0) {
        tbody.innerHTML = `
            <tr><td colspan="6" class="empty-state">
                <i class="fas fa-comments"></i>
                <p>لا توجد محادثات</p>
            </td></tr>
        `;
        return;
    }
    
    const start = (currentPages.chats - 1) * PAGE_SIZE;
    const end = start + PAGE_SIZE;
    const paginatedChats = chats.slice(start, end);
    
    tbody.innerHTML = paginatedChats.map((chat, index) => `
        <tr>
            <td>${start + index + 1}</td>
            <td>${chat.user1_name || 'User ' + chat.user1_id}</td>
            <td>${chat.user2_name || 'User ' + chat.user2_id}</td>
            <td class="post-caption">${truncateText(chat.last_message || 'لا توجد رسائل', 40)}</td>
            <td>${formatDate(chat.created_at)}</td>
            <td>
                <div class="action-buttons">
                    <button class="btn btn-sm btn-info" onclick="viewChat(${chat.id})" title="عرض المحادثة">
                        <i class="fas fa-eye"></i>
                    </button>
                    <button class="btn btn-sm btn-danger" onclick="deleteChat(${chat.id})" title="حذف">
                        <i class="fas fa-trash"></i>
                    </button>
                </div>
            </td>
        </tr>
    `).join('');
    
    renderPagination('chats', chats.length);
}

function filterChats() {
    const searchTerm = document.getElementById('chats-search').value.toLowerCase();
    
    let filtered = allData.chats.filter(chat => {
        return (chat.user1_name && chat.user1_name.toLowerCase().includes(searchTerm)) ||
               (chat.user2_name && chat.user2_name.toLowerCase().includes(searchTerm)) ||
               (chat.last_message && chat.last_message.toLowerCase().includes(searchTerm));
    });
    
    currentPages.chats = 1;
    renderChats(filtered);
}

async function deleteChat(id) {
    if (!confirm('هل أنت متأكد من حذف هذه المحادثة؟')) return;
    
    try {
        const response = await fetch(`${API_URL}/chats/${id}`, {
            method: 'DELETE'
        });
        
        if (response.ok) {
            showToast('تم حذف المحادثة بنجاح', 'success');
            loadChats();
            loadStats();
            logActivity('chat', 'delete', `تم حذف المحادثة #${id}`);
        } else {
            throw new Error('Failed to delete chat');
        }
    } catch (error) {
        showToast('خطأ في حذف المحادثة', 'error');
    }
}

function viewChat(id) {
    showToast(`عرض المحادثة #${id}`, 'info');
    // TODO: Implement chat messages view modal
}

// ============================================
// ANALYTICS
// ============================================

function loadAnalytics() {
    createUsersGrowthChart();
    createPostsTypeChart();
    createPositionsChart();
    createActivityChart();
}

function createUsersGrowthChart() {
    const ctx = document.getElementById('usersGrowthChart');
    if (!ctx) return;
    
    // Destroy existing chart if any
    if (window.usersGrowthChart && typeof window.usersGrowthChart.destroy === 'function') {
        window.usersGrowthChart.destroy();
    }
    
    window.usersGrowthChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو'],
            datasets: [{
                label: 'المستخدمون الجدد',
                data: [12, 19, 25, 32, 45, 58],
                borderColor: 'rgb(75, 192, 192)',
                backgroundColor: 'rgba(75, 192, 192, 0.2)',
                tension: 0.4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: true,
                    position: 'bottom'
                }
            }
        }
    });
}

function createPostsTypeChart() {
    const ctx = document.getElementById('postsTypeChart');
    if (!ctx) return;
    
    if (window.postsTypeChart && typeof window.postsTypeChart.destroy === 'function') {
        window.postsTypeChart.destroy();
    }
    
    window.postsTypeChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['صور', 'فيديو', 'نص'],
            datasets: [{
                data: [45, 30, 25],
                backgroundColor: [
                    'rgba(255, 99, 132, 0.8)',
                    'rgba(54, 162, 235, 0.8)',
                    'rgba(255, 206, 86, 0.8)'
                ]
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom'
                }
            }
        }
    });
}

function createPositionsChart() {
    const ctx = document.getElementById('positionsChart');
    if (!ctx) return;
    
    if (window.positionsChart && typeof window.positionsChart.destroy === 'function') {
        window.positionsChart.destroy();
    }
    
    window.positionsChart = new Chart(ctx, {
        type: 'pie',
        data: {
            labels: ['حارس مرمى', 'مدافع', 'وسط', 'مهاجم'],
            datasets: [{
                data: [10, 35, 30, 25],
                backgroundColor: [
                    'rgba(255, 99, 132, 0.8)',
                    'rgba(54, 162, 235, 0.8)',
                    'rgba(255, 206, 86, 0.8)',
                    'rgba(75, 192, 192, 0.8)'
                ]
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom'
                }
            }
        }
    });
}

function createActivityChart() {
    const ctx = document.getElementById('activityChart');
    if (!ctx) return;
    
    if (window.activityChart && typeof window.activityChart.destroy === 'function') {
        window.activityChart.destroy();
    }
    
    window.activityChart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'],
            datasets: [{
                label: 'المنشورات',
                data: [12, 19, 15, 25, 22, 30, 28],
                backgroundColor: 'rgba(54, 162, 235, 0.8)'
            }, {
                label: 'المحادثات',
                data: [15, 25, 20, 30, 28, 35, 32],
                backgroundColor: 'rgba(75, 192, 192, 0.8)'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom'
                }
            },
            scales: {
                y: {
                    beginAtZero: true
                }
            }
        }
    });
}

// ============================================
// REPORTS & MODERATION
// ============================================

function loadReports() {
    // Mock data for now
    document.getElementById('reported-posts-count').textContent = '0';
    document.getElementById('reported-users-count').textContent = '0';
    document.getElementById('reported-chats-count').textContent = '0';
    
    // TODO: Implement actual reports loading from API
}

// ============================================
// NOTIFICATIONS
// ============================================

async function sendNotification() {
    const type = document.getElementById('notification-type').value;
    const title = document.getElementById('notification-title').value;
    const message = document.getElementById('notification-message').value;
    const userId = document.getElementById('specific-user-id').value;
    
    if (!title || !message) {
        showToast('الرجاء إدخال العنوان والرسالة', 'error');
        return;
    }
    
    try {
        const response = await fetch(`${API_URL}/notifications/send`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ type, title, message, userId })
        });
        
        if (response.ok) {
            showToast('تم إرسال الإشعار بنجاح', 'success');
            document.getElementById('notification-title').value = '';
            document.getElementById('notification-message').value = '';
            addNotificationToHistory(type, title, message);
            logActivity('system', 'create', `تم إرسال إشعار: ${title}`);
        } else {
            throw new Error('Failed to send notification');
        }
    } catch (error) {
        showToast('خطأ في إرسال الإشعار', 'error');
    }
}

function addNotificationToHistory(type, title, message) {
    const historyList = document.getElementById('notification-history-list');
    
    if (historyList.querySelector('.empty-state')) {
        historyList.innerHTML = '';
    }
    
    const notificationItem = document.createElement('div');
    notificationItem.className = 'notification-history-item';
    notificationItem.innerHTML = `
        <div class="notification-header">
            <strong>${title}</strong>
            <span class="badge badge-info">${translateNotificationType(type)}</span>
        </div>
        <p>${message}</p>
        <small>${new Date().toLocaleString('ar-SA')}</small>
    `;
    
    historyList.insertBefore(notificationItem, historyList.firstChild);
}

// ============================================
// SETTINGS
// ============================================

function saveUploadSettings() {
    const maxImageSize = document.getElementById('max-image-size').value;
    const maxVideoSize = document.getElementById('max-video-size').value;
    
    // TODO: Save to backend
    showToast('تم حفظ إعدادات الرفع', 'success');
    logActivity('system', 'update', 'تم تحديث إعدادات الرفع');
}

function saveSecuritySettings() {
    const enableModeration = document.getElementById('enable-moderation').checked;
    const requireApproval = document.getElementById('require-approval').checked;
    
    // TODO: Save to backend
    showToast('تم حفظ إعدادات الأمان', 'success');
    logActivity('system', 'update', 'تم تحديث إعدادات الأمان');
}

function toggleMaintenanceMode() {
    const enabled = document.getElementById('maintenance-mode').checked;
    const message = document.getElementById('maintenance-message').value;
    
    if (confirm(`هل أنت متأكد من ${enabled ? 'تفعيل' : 'إيقاف'} وضع الصيانة؟`)) {
        // TODO: Save to backend
        showToast(`تم ${enabled ? 'تفعيل' : 'إيقاف'} وضع الصيانة`, 'success');
        logActivity('system', 'update', `تم ${enabled ? 'تفعيل' : 'إيقاف'} وضع الصيانة`);
    }
}

function backupDatabase() {
    showToast('جاري إنشاء نسخة احتياطية...', 'info');
    // TODO: Implement backup
    setTimeout(() => {
        showToast('تم إنشاء النسخة الاحتياطية بنجاح', 'success');
        logActivity('system', 'create', 'تم إنشاء نسخة احتياطية');
    }, 2000);
}

function clearCache() {
    if (confirm('هل أنت متأكد من مسح الذاكرة المؤقتة؟')) {
        showToast('تم مسح الذاكرة المؤقتة', 'success');
        logActivity('system', 'delete', 'تم مسح الذاكرة المؤقتة');
    }
}

function confirmDatabaseReset() {
    if (confirm('⚠️ تحذير: هذا سيحذف جميع البيانات! هل أنت متأكد؟')) {
        if (confirm('هل أنت متأكد تماماً؟ لا يمكن التراجع عن هذا الإجراء!')) {
            showToast('تم إعادة تعيين قاعدة البيانات', 'success');
            logActivity('system', 'delete', 'تم إعادة تعيين قاعدة البيانات');
        }
    }
}

// ============================================
// ACTIVITY LOGS
// ============================================

function loadLogs() {
    renderLogs();
}

function renderLogs(filteredData = null) {
    const logs = filteredData || allData.logs;
    const tbody = document.getElementById('logs-tbody');
    
    if (logs.length === 0) {
        tbody.innerHTML = `
            <tr><td colspan="6" class="empty-state">
                <i class="fas fa-clipboard-list"></i>
                <p>لا توجد سجلات بعد</p>
            </td></tr>
        `;
        return;
    }
    
    const start = (currentPages.logs - 1) * PAGE_SIZE;
    const end = start + PAGE_SIZE;
    const paginatedLogs = logs.slice(start, end);
    
    tbody.innerHTML = paginatedLogs.map((log, index) => `
        <tr>
            <td>${start + index + 1}</td>
            <td><span class="badge badge-${getLogTypeBadge(log.type)}">${log.type}</span></td>
            <td><span class="badge badge-${getLogActionBadge(log.action)}">${log.action}</span></td>
            <td>${log.details}</td>
            <td>المسؤول</td>
            <td>${log.timestamp}</td>
        </tr>
    `).join('');
    
    renderPagination('logs', logs.length);
}

function logActivity(type, action, details) {
    const log = {
        type,
        action,
        details,
        timestamp: new Date().toLocaleString('ar-SA')
    };
    
    allData.logs.unshift(log);
    
    // Keep only last 1000 logs
    if (allData.logs.length > 1000) {
        allData.logs = allData.logs.slice(0, 1000);
    }
}

function filterLogs() {
    const typeFilter = document.getElementById('logs-type-filter').value;
    const actionFilter = document.getElementById('logs-action-filter').value;
    const dateFilter = document.getElementById('logs-date-filter').value;
    
    let filtered = allData.logs.filter(log => {
        const matchesType = !typeFilter || log.type === typeFilter;
        const matchesAction = !actionFilter || log.action === actionFilter;
        const matchesDate = !dateFilter || log.timestamp.startsWith(dateFilter);
        
        return matchesType && matchesAction && matchesDate;
    });
    
    currentPages.logs = 1;
    renderLogs(filtered);
}

function clearLogs() {
    if (confirm('هل أنت متأكد من مسح جميع السجلات؟')) {
        allData.logs = [];
        renderLogs();
        showToast('تم مسح السجلات', 'success');
    }
}

// ============================================
// BULK ACTIONS
// ============================================

function toggleSelectAll(type) {
    const checkboxes = document.querySelectorAll(`.${type}-checkbox`);
    const selectAllCheckbox = document.getElementById(`select-all-${type}`);
    
    checkboxes.forEach(checkbox => {
        checkbox.checked = selectAllCheckbox.checked;
        const id = parseInt(checkbox.dataset.id);
        if (selectAllCheckbox.checked) {
            selectedItems[type].add(id);
        } else {
            selectedItems[type].delete(id);
        }
    });
    
    updateBulkButtons(type);
}

function toggleUserSelection(id) {
    if (selectedItems.users.has(id)) {
        selectedItems.users.delete(id);
    } else {
        selectedItems.users.add(id);
    }
    updateBulkButtons('users');
}

function toggleApprovalSelection(id) {
    if (selectedItems.approvals.has(id)) {
        selectedItems.approvals.delete(id);
    } else {
        selectedItems.approvals.add(id);
    }
    updateBulkButtons('approvals');
}

function togglePostSelection(id) {
    if (selectedItems.posts.has(id)) {
        selectedItems.posts.delete(id);
    } else {
        selectedItems.posts.add(id);
    }
    updateBulkButtons('posts');
}

function updateBulkButtons(type) {
    const count = selectedItems[type].size;
    
    if (type === 'users') {
        const deleteBtn = document.getElementById('bulk-delete-users');
        deleteBtn.style.display = count > 0 ? 'inline-block' : 'none';
        deleteBtn.innerHTML = `<i class="fas fa-trash"></i> حذف المحدد (${count})`;
    } else if (type === 'approvals') {
        const approveBtn = document.getElementById('bulk-approve-users');
        approveBtn.style.display = count > 0 ? 'inline-block' : 'none';
        approveBtn.innerHTML = `<i class="fas fa-check"></i> موافقة المحدد (${count})`;
    } else if (type === 'posts') {
        const deleteBtn = document.getElementById('bulk-delete-posts');
        deleteBtn.style.display = count > 0 ? 'inline-block' : 'none';
        deleteBtn.innerHTML = `<i class="fas fa-trash"></i> حذف المحدد (${count})`;
    }
}

async function bulkDeleteUsers() {
    const count = selectedItems.users.size;
    if (!confirm(`هل أنت متأكد من حذف ${count} مستخدم؟`)) return;
    
    try {
        const promises = Array.from(selectedItems.users).map(id => 
            fetch(`${API_URL}/users/${id}`, { method: 'DELETE' })
        );
        
        await Promise.all(promises);
        showToast(`تم حذف ${count} مستخدم بنجاح`, 'success');
        selectedItems.users.clear();
        loadUsers();
        loadStats();
        logActivity('user', 'delete', `تم حذف ${count} مستخدم (إجراء جماعي)`);
    } catch (error) {
        showToast('خطأ في الحذف الجماعي', 'error');
    }
}

async function bulkApproveUsers() {
    const count = selectedItems.approvals.size;
    if (!confirm(`هل أنت متأكد من الموافقة على ${count} مستخدم؟`)) return;
    
    try {
        const promises = Array.from(selectedItems.approvals).map(id => 
            fetch(`${API_URL}/approvals/${id}/approve`, { method: 'POST' })
        );
        
        await Promise.all(promises);
        showToast(`تمت الموافقة على ${count} مستخدم بنجاح`, 'success');
        selectedItems.approvals.clear();
        loadApprovals();
        loadStats();
        logActivity('user', 'approve', `تمت الموافقة على ${count} مستخدم (إجراء جماعي)`);
    } catch (error) {
        showToast('خطأ في الموافقة الجماعية', 'error');
    }
}

async function bulkDeletePosts() {
    const count = selectedItems.posts.size;
    if (!confirm(`هل أنت متأكد من حذف ${count} منشور؟`)) return;
    
    try {
        const promises = Array.from(selectedItems.posts).map(id => 
            fetch(`${API_URL}/posts/${id}`, { method: 'DELETE' })
        );
        
        await Promise.all(promises);
        showToast(`تم حذف ${count} منشور بنجاح`, 'success');
        selectedItems.posts.clear();
        loadPosts();
        loadStats();
        logActivity('post', 'delete', `تم حذف ${count} منشور (إجراء جماعي)`);
    } catch (error) {
        showToast('خطأ في الحذف الجماعي', 'error');
    }
}

// ============================================
// EXPORT TO CSV
// ============================================

function exportToCSV(type) {
    let data, filename, headers;
    
    switch(type) {
        case 'users':
            data = allData.users;
            filename = 'users.csv';
            headers = ['ID', 'Name', 'Email', 'Position', 'Status', 'Created At'];
            break;
        case 'posts':
            data = allData.posts;
            filename = 'posts.csv';
            headers = ['ID', 'Author', 'Caption', 'Media Type', 'Created At'];
            break;
        case 'chats':
            data = allData.chats;
            filename = 'chats.csv';
            headers = ['ID', 'User1', 'User2', 'Last Message', 'Created At'];
            break;
        case 'logs':
            data = allData.logs;
            filename = 'activity_logs.csv';
            headers = ['Type', 'Action', 'Details', 'Timestamp'];
            break;
        default:
            return;
    }
    
    if (data.length === 0) {
        showToast('لا توجد بيانات للتصدير', 'error');
        return;
    }
    
    let csv = headers.join(',') + '\n';
    
    data.forEach(item => {
        let row = [];
        switch(type) {
            case 'users':
                row = [item.id, item.name, item.email, item.position, item.status, item.created_at];
                break;
            case 'posts':
                row = [item.id, item.author_name, item.caption.replace(/,/g, ';'), item.media_type, item.created_at];
                break;
            case 'chats':
                row = [item.id, item.user1_name, item.user2_name, item.last_message, item.created_at];
                break;
            case 'logs':
                row = [item.type, item.action, item.details, item.timestamp];
                break;
        }
        csv += row.join(',') + '\n';
    });
    
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = filename;
    link.click();
    
    showToast('تم تصدير البيانات بنجاح', 'success');
    logActivity('system', 'create', `تم تصدير ${type} إلى CSV`);
}

// ============================================
// PAGINATION
// ============================================

function renderPagination(type, totalItems) {
    const paginationDiv = document.getElementById(`${type}-pagination`);
    if (!paginationDiv) return;
    
    const totalPages = Math.ceil(totalItems / PAGE_SIZE);
    
    if (totalPages <= 1) {
        paginationDiv.innerHTML = '';
        return;
    }
    
    let html = '<div class="pagination-controls">';
    
    // Previous button
    html += `<button class="pagination-btn" ${currentPages[type] === 1 ? 'disabled' : ''} 
             onclick="changePage('${type}', ${currentPages[type] - 1})">
             <i class="fas fa-chevron-right"></i>
             </button>`;
    
    // Page numbers
    for (let i = 1; i <= totalPages; i++) {
        if (i === 1 || i === totalPages || (i >= currentPages[type] - 2 && i <= currentPages[type] + 2)) {
            html += `<button class="pagination-btn ${i === currentPages[type] ? 'active' : ''}" 
                     onclick="changePage('${type}', ${i})">${i}</button>`;
        } else if (i === currentPages[type] - 3 || i === currentPages[type] + 3) {
            html += `<span class="pagination-ellipsis">...</span>`;
        }
    }
    
    // Next button
    html += `<button class="pagination-btn" ${currentPages[type] === totalPages ? 'disabled' : ''} 
             onclick="changePage('${type}', ${currentPages[type] + 1})">
             <i class="fas fa-chevron-left"></i>
             </button>`;
    
    html += `<span class="pagination-info">صفحة ${currentPages[type]} من ${totalPages}</span>`;
    html += '</div>';
    
    paginationDiv.innerHTML = html;
}

function changePage(type, page) {
    currentPages[type] = page;
    
    switch(type) {
        case 'users':
            renderUsers();
            break;
        case 'approvals':
            renderApprovals();
            break;
        case 'posts':
            renderPosts();
            break;
        case 'chats':
            renderChats();
            break;
        case 'logs':
            renderLogs();
            break;
    }
    
    // Scroll to top
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

// ============================================
// MODAL MANAGEMENT
// ============================================

function closeModal(modalId) {
    document.getElementById(modalId).style.display = 'none';
}

// Close modal when clicking outside
window.onclick = function(event) {
    if (event.target.classList.contains('modal')) {
        event.target.style.display = 'none';
    }
}

// ============================================
// UTILITY FUNCTIONS
// ============================================

function formatDate(dateString) {
    if (!dateString) return '-';
    const date = new Date(dateString);
    return date.toLocaleDateString('ar-SA', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

function truncateText(text, maxLength) {
    if (!text) return '-';
    return text.length > maxLength ? text.substring(0, maxLength) + '...' : text;
}

function translatePosition(position) {
    if (!position) return '-';
    
    const positions = {
        'goalkeeper': 'حارس مرمى',
        'defender': 'مدافع',
        'midfielder': 'وسط',
        'forward': 'مهاجم'
    };
    return positions[position] || position;
}

function translateStatus(status) {
    const statusMap = {
        'active': 'نشط',
        'pending': 'قيد المراجعة'
    };
    return statusMap[status] || status;
}

function translateMediaType(type) {
    const types = {
        'image': 'صورة',
        'video': 'فيديو',
        'text': 'نص',
        null: 'نص'
    };
    return types[type] || 'نص';
}

function translateNotificationType(type) {
    const types = {
        'all': 'الكل',
        'active': 'النشطون',
        'specific': 'محدد'
    };
    return types[type] || type;
}

function getStatusColor(status) {
    const colors = {
        'active': 'success',
        'pending': 'warning'
    };
    return colors[status] || 'secondary';
}

function getMediaBadge(type) {
    const badges = {
        'image': 'primary',
        'video': 'info',
        'text': 'secondary',
        null: 'secondary'
    };
    return badges[type] || 'secondary';
}

function getLogTypeBadge(type) {
    const badges = {
        'user': 'primary',
        'post': 'info',
        'chat': 'success',
        'system': 'warning'
    };
    return badges[type] || 'secondary';
}

function getLogActionBadge(action) {
    const badges = {
        'create': 'success',
        'update': 'info',
        'delete': 'danger',
        'approve': 'success',
        'reject': 'danger',
        'view': 'secondary'
    };
    return badges[action] || 'secondary';
}

function refreshAll() {
    showToast('جاري تحديث البيانات...', 'info');
    loadStats();
    
    // Reload current tab data
    const activeTab = document.querySelector('.tab-content.active');
    if (activeTab) {
        const tabId = activeTab.id.replace('-tab', '');
        switch(tabId) {
            case 'users':
                loadUsers();
                break;
            case 'approvals':
                loadApprovals();
                break;
            case 'posts':
                loadPosts();
                break;
            case 'chats':
                loadChats();
                break;
            case 'analytics':
                loadAnalytics();
                break;
            case 'reports':
                loadReports();
                break;
            case 'logs':
                loadLogs();
                break;
        }
    }
    
    setTimeout(() => {
        showToast('تم تحديث البيانات', 'success');
    }, 1000);
}
