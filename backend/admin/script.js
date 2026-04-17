const API_BASE = "/api/admin";
const ADMIN_KEY = "another_super_secret_admin_key_for_postman_access";
const ADS_API_BASE = "/api/ads";


let currentUserId = null;
let currentPostId = null;
let currentPage = {
  users: 1,
  vipUsers: 1,
  posts: 1,
  comments: 1,
  reports: 1,
  audit: 1
};

const ITEMS_PER_PAGE = 10;

// ✅ ensure local storage has it (so adminHeaders() works)
if (!localStorage.getItem("ADMIN_KEY")) {
  localStorage.setItem("ADMIN_KEY", ADMIN_KEY);
}

/* =========================
   UTILITY FUNCTIONS
========================= */

function openModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) modal.classList.add("show");
}

function closeModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) modal.classList.remove("show");
}

function adminHeaders() {
  const key = localStorage.getItem("ADMIN_KEY") || "";
  return {
    "Accept": "application/json",
    "Content-Type": "application/json",
    "x-admin-key": key,
  };
}

let currentPasswordUserId = null;


function openChangePassword(userId) {
  if (!userId || userId === 'null' || userId == null) {
    alert("معرف المستخدم غير صحيح");
    return;
  }

  currentPasswordUserId = Number(userId);

  // label from user detail modal values (already filled)
  const name = document.getElementById('userDetailName')?.textContent || '-';
  const email = document.getElementById('userDetailEmail')?.textContent || '-';
  document.getElementById("cp_userLabel").textContent = `${name} (${email}) #${currentPasswordUserId}`;

  document.getElementById("cp_newPass").value = "";
  document.getElementById("cp_confirmPass").value = "";
  openModal("changePasswordModal");
}

function switchView(view, event) {
  if (event) event.preventDefault();
  
  // Hide all sections
  document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
  
  // Show selected section
  const sectionId = view + 'Section';
  const section = document.getElementById(sectionId);
  if (section) {
    section.classList.add('active');
  }
  
  // Update sidebar active state
  document.querySelectorAll('.sidebar-menu a').forEach(a => a.classList.remove('active'));
  event.target.classList.add('active');
  
  // Load data for the view
  if (view === 'users') loadUsers(1);
  else if (view === 'vipUsers') loadVipUsers(1);
  else if (view === 'posts') loadPosts(1);
  else if (view === 'comments') loadComments(1);
  else if (view === 'reports') loadReports(1);
  else if (view === 'audit') loadAuditLogs(1);
  else if (view === 'dashboard') loadDashboard();
  else if (view === 'ads') loadAds();
}

function formatDate(dateString) {
  if (!dateString) return '-';
  return new Date(dateString).toLocaleDateString('ar-SA', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
}

async function loadVipUsers(page = 1) {
  try {
    currentPage.vipUsers = page;
    const offset = (page - 1) * ITEMS_PER_PAGE;

    const statusFilter = document.getElementById('vipUserStatusFilter')?.value || '';
    const typeFilter = document.getElementById('vipUserTypeFilter')?.value || '';
    const searchQuery = document.getElementById('vipUserSearch')?.value || '';

    // ✅ important: is_vip=1
    let url = `${API_BASE}/users?limit=${ITEMS_PER_PAGE}&offset=${offset}&is_vip=1`;
    if (statusFilter) url += `&status=${statusFilter}`;
    if (typeFilter) url += `&type=${typeFilter}`;
    if (searchQuery) url += `&search=${searchQuery}`;

    const res = await fetch(url, {
      headers: { "x-admin-key": ADMIN_KEY }
    });

    const json = await res.json();
    if (!json.success) {
      console.error('Failed to load VIP users:', json);
      return;
    }

    const tbody = document.getElementById("vipUsersTable");
    tbody.innerHTML = "";

    if (!json.data || json.data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="8" style="text-align: center; padding: 20px;">لا توجد بيانات</td></tr>';
      renderPagination('vipUsersPagination', page, 1, 'loadVipUsers');
      return;
    }

    json.data.forEach(u => {
      const statusBadge = getStatusBadge(u.status);
      const vip = Number(u.is_vip) === 1;

      tbody.innerHTML += `
        <tr>
          <td>${u.id}</td>
          <td>${u.name || '-'}</td>
          <td>${u.email || '-'}</td>
          <td>${u.phone || '-'}</td> 
          <td>${u.type || '-'}</td>
          <td>${statusBadge}</td>
          <td>${u.rating || '0.00'}</td>

          <td style="text-align:center;">
            <button
              class="btn btn-sm"
              style="background:${vip ? '#f1c40f' : '#ecf0f1'}; color:${vip ? '#2c3e50' : '#7f8c8d'};"
              onclick="toggleVip(${u.id}, ${vip ? 1 : 0}, this)"
              title="Toggle VIP">
              ${vip ? '✅ VIP' : '☆ VIP'}
            </button>
          </td>

          <td>
            <button class="btn btn-sm" onclick="viewUserDetails(${u.id})" title="عرض">👁️</button>
            <button class="btn btn-primary" onclick="editUserModal(${u.id})">تعديل</button>
            <button class="btn btn-sm" onclick="banUser(${u.id})" title="حظر">⛔</button>
          </td>
        </tr>
      `;
    });

    const totalPages = Math.ceil((json.total || 0) / ITEMS_PER_PAGE);
    renderPagination('vipUsersPagination', page, totalPages, 'loadVipUsers');

  } catch (error) {
    console.error('Error loading VIP users:', error);
  }
}

async function viewUserDetails(userId) {
  if (!userId || userId === 'null' || userId == null) {
    console.error('viewUserDetails called with null userId');
    return;
  }

  userId = Number(userId);

  try {
    const res = await fetch(`${API_BASE}/users/${userId}`, {
      headers: { "x-admin-key": ADMIN_KEY }
    });

    const json = await res.json();
    if (!json.success || !json.data) {
      alert('فشل تحميل بيانات المستخدم');
      return;
    }

    const user = json.data;
    currentUserId = userId;

    // Fill all user data
    document.getElementById('userDetailName').textContent = user.name || '-';
    document.getElementById('userDetailEmail').textContent = user.email || '-';
    document.getElementById('userDetailPhone').textContent = user.phone || '-';
    document.getElementById('userDetailType').textContent = user.type || '-';
    document.getElementById('userDetailStatus').textContent = user.status || '-';
    document.getElementById('userDetailPosition').textContent = user.position || '-';
    document.getElementById('userDetailClub').textContent = user.current_club || '-'; // ✅ fixed
    document.getElementById('userDetailAge').textContent = user.age || '-';
    document.getElementById('userDetailCreated').textContent = user.created_at || '-';
    document.getElementById('userDetailBio').textContent = user.bio || 'لا يوجد';

    // Handle profile photo
    const photo = document.getElementById('userDetailPhoto');
    const photoPlaceholder = document.getElementById('userDetailPhotoPlaceholder');

    if (user.profile_photo_url) { // ✅ fixed
      photo.src = user.profile_photo_url;
      photo.style.display = 'block';
      photoPlaceholder.style.display = 'none';
    } else {
      photo.style.display = 'none';
      photoPlaceholder.style.display = 'flex';
    }

    // Handle cover photo
    const cover = document.getElementById('userDetailCover');
    const coverPlaceholder = document.getElementById('userDetailCoverPlaceholder');

    if (user.cover_photo_url) { // ✅ fixed
      cover.src = user.cover_photo_url;
      cover.style.display = 'block';
      coverPlaceholder.style.display = 'none';
    } else {
      cover.style.display = 'none';
      coverPlaceholder.style.display = 'flex';
    }

    // Load user posts
    loadUserPosts(userId);

    // Open modal last to ensure all data is loaded
    openModal('userDetailModal');

  } catch (error) {
    console.error('Error loading user details:', error);
    alert('حدث خطأ في تحميل البيانات');
  }
}

async function loadUserPosts(userId) {
  const container = document.getElementById("userPostsContainer");
  if (!container) return;

  container.innerHTML = '<div style="text-align:center; padding:20px; color:#999;">جاري تحميل المنشورات...</div>';

  try {
    const res = await fetch(`${API_BASE}/posts?user_id=${userId}&limit=20`, {
      headers: { "x-admin-key": ADMIN_KEY }
    });

    const json = await res.json();

    if (!json.success) {
      container.innerHTML = '<div style="text-align:center; padding:20px; color:#e74c3c;">خطأ في تحميل المنشورات</div>';
      return;
    }

    container.innerHTML = '';

    if (!json.data || json.data.length === 0) {
      container.innerHTML = '<div style="text-align:center; padding:40px; color:#999;">لا توجد منشورات</div>';
      return;
    }

    json.data.forEach(p => {
      const statusColor = p.status === 'active' ? '#27ae60' : p.status === 'rejected' ? '#e74c3c' : '#f39c12';
      const statusText = p.status === 'active' ? 'نشط' : p.status === 'rejected' ? 'مرفوض' : 'معلق';

      // ✅ only ONE media block — video OR image, not both
      let mediaHtml = '';
      if (p.media_url) {
        if (p.media_type === 'video') {
          mediaHtml = `
            <video 
              src="${p.media_url}" 
              controls 
              style="width:100%; max-height:200px; border-radius:8px; margin:8px 0; background:#000; display:block;"
              onerror="this.outerHTML='<div style=padding:10px;color:#999;text-align:center;>⚠️ فيديو غير متاح</div>'"
            ></video>`;
        } else {
          mediaHtml = `
            <img 
              src="${p.media_url}" 
              style="width:100%; max-height:200px; object-fit:cover; border-radius:8px; margin:8px 0; display:block;"
              onerror="this.outerHTML='<div style=padding:10px;color:#999;text-align:center;>⚠️ صورة غير متاحة</div>'"
            />`;
        }
      }

      const card = document.createElement('div');
      card.style.cssText = `
        background: #fff;
        border: 1px solid #e2e8f0;
        border-radius: 10px;
        padding: 12px;
        margin-bottom: 12px;
        box-shadow: 0 1px 4px rgba(0,0,0,0.06);
      `;

      card.innerHTML = `
        <!-- Header -->
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;">
          <span style="font-weight:600; color:#555; font-size:13px;">#${p.id}</span>
          <span style="
            background:${statusColor}; 
            color:white; 
            padding:3px 10px; 
            border-radius:12px; 
            font-size:11px;
            font-weight:600;
          ">${statusText}</span>
        </div>

        <!-- Caption -->
        ${p.caption ? `<div style="font-size:13px; color:#333; margin-bottom:6px; line-height:1.5;">${p.caption.substring(0, 100)}${p.caption.length > 100 ? '...' : ''}</div>` : '<div style="font-size:12px;color:#aaa;margin-bottom:6px;">بدون وصف</div>'}

        <!-- Media -->
        ${mediaHtml}

        <!-- Stats -->
        <div style="display:flex; gap:12px; font-size:12px; color:#888; margin-bottom:10px;">
          <span>👁️ ${p.views || 0} مشاهدة</span>
          <span>💬 ${p.comment_count || 0} تعليق</span>
        </div>

        <!-- Actions -->
        <div style="display:grid; grid-template-columns:1fr 1fr 1fr 1fr; gap:6px;">
          <button 
            onclick="viewPostDetails(${p.id})" 
            style="padding:6px; background:#6c757d; color:white; border:none; border-radius:6px; cursor:pointer; font-size:12px;"
            title="عرض التفاصيل">
            👁️ عرض
          </button>
          <button 
            onclick="approvePostInline(${p.id}, this)" 
            style="padding:6px; background:#27ae60; color:white; border:none; border-radius:6px; cursor:pointer; font-size:12px;"
            title="موافقة">
            ✓ قبول
          </button>
          <button 
            onclick="rejectPostInline(${p.id}, this)" 
            style="padding:6px; background:#f39c12; color:white; border:none; border-radius:6px; cursor:pointer; font-size:12px;"
            title="رفض">
            ✗ رفض
          </button>
          <button 
            onclick="deletePostInline(${p.id}, this)" 
            style="padding:6px; background:#e74c3c; color:white; border:none; border-radius:6px; cursor:pointer; font-size:12px;"
            title="حذف">
            🗑️ حذف
          </button>
        </div>
      `;

      container.appendChild(card);
    });

  } catch (err) {
    console.error(err);
    container.innerHTML = '<div style="text-align:center; padding:20px; color:#e74c3c;">حدث خطأ في التحميل</div>';
  }
}

// ✅ inline actions that update the card UI without closing the modal
async function approvePostInline(id, btn) {
  btn.disabled = true;
  btn.textContent = '...';
  try {
    const res = await fetch(`${API_BASE}/posts/${id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json", "x-admin-key": ADMIN_KEY },
      body: JSON.stringify({ status: 'active' })
    });
    const json = await res.json();
    if (json.success) {
      // update badge in the same card
      const card = btn.closest('div[style]');
      const badge = card.querySelector('span[style*="border-radius:12px"]');
      if (badge) { badge.style.background = '#27ae60'; badge.textContent = 'نشط'; }
      btn.textContent = '✓ قبول';
    } else {
      alert(json.message || 'فشل');
    }
  } catch(e) { alert('حدث خطأ'); }
  finally { btn.disabled = false; }
}

async function rejectPostInline(id, btn) {
  btn.disabled = true;
  btn.textContent = '...';
  try {
    const res = await fetch(`${API_BASE}/posts/${id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json", "x-admin-key": ADMIN_KEY },
      body: JSON.stringify({ status: 'pending' })  // ✅ fixed
    });
    const json = await res.json();
    if (json.success) {
      const card = btn.closest('div[style]');
      const badge = card.querySelector('span[style*="border-radius:12px"]');
      if (badge) { badge.style.background = '#f39c12'; badge.textContent = 'معلق'; }  // ✅ fixed
      btn.textContent = '✗ رفض';
    } else {
      alert(json.message || 'فشل');
    }
  } catch(e) { alert('حدث خطأ'); }
  finally { btn.disabled = false; }
}

async function deletePostInline(id, btn) {
  if (!confirm('هل تريد حذف هذا المنشور؟')) return;
  btn.disabled = true;
  btn.textContent = '...';
  try {
    const res = await fetch(`${API_BASE}/posts/${id}`, {
      method: "DELETE",
      headers: { "x-admin-key": ADMIN_KEY }
    });
    const json = await res.json();
    if (json.success) {
      // remove the card from DOM
      const card = btn.closest('div[style]');
      card.style.transition = 'opacity 0.3s';
      card.style.opacity = '0';
      setTimeout(() => card.remove(), 300);
    } else {
      alert(json.message || 'فشل الحذف');
      btn.disabled = false;
      btn.textContent = '🗑️ حذف';
    }
  } catch(e) {
    alert('حدث خطأ');
    btn.disabled = false;
    btn.textContent = '🗑️ حذف';
  }
}

function editUserModal(userId) {
  if (!userId || userId === 'null' || userId == null) {
    console.error('editUserModal called with null userId');
    return;
  }

  userId = Number(userId);
  currentUserId = userId;

  fetch(`${API_BASE}/users/${userId}`, {
    headers: { "x-admin-key": ADMIN_KEY }
  })
    .then(r => r.json())
    .then(json => {
      if (json.success && json.data) {
        const user = json.data;
        document.getElementById('editUserName').value = user.name || '';
        document.getElementById('editUserType').value = user.type || 'player';
        document.getElementById('editUserStatus').value = user.status || 'pending';
        openModal('editUserModal');
      } else {
        alert(json.message || 'فشل تحميل المستخدم');
      }
    })
    .catch(err => {
      console.error('Error:', err);
      alert('حدث خطأ');
    });
}



function formatTime(dateString) {
  if (!dateString) return '-';
  return new Date(dateString).toLocaleTimeString('ar-SA');
}

function getStatusBadge(status) {
  const statusMap = {
    'active':     '<span style="background:#27ae60;color:white;padding:5px 10px;border-radius:3px;font-size:12px;">نشط</span>',
    'pending':    '<span style="background:#e74c3c;color:white;padding:5px 10px;border-radius:3px;font-size:12px;">معلق</span>',
    'processing': '<span style="background:#3498db;color:white;padding:5px 10px;border-radius:3px;font-size:12px;">قيد المعالجة</span>',
    'failed':     '<span style="background:#7f8c8d;color:white;padding:5px 10px;border-radius:3px;font-size:12px;">فشل</span>',
  };
  return statusMap[status] || `<span style="background:#95a5a6;color:white;padding:5px 10px;border-radius:3px;font-size:12px;">${status || '-'}</span>`;
}



/* =========================
   DASHBOARD
========================= */

async function loadDashboard() {
  try {
    const usersRes = await fetch(`${API_BASE}/users?limit=1`, {
      headers: { "x-admin-key": ADMIN_KEY }
    });
    const usersData = await usersRes.json();
    
    const postsRes = await fetch(`${API_BASE}/posts?limit=1`, {
      headers: { "x-admin-key": ADMIN_KEY }
    });
    const postsData = await postsRes.json();
    
    if (usersData.success) {
      document.getElementById('totalUsers').textContent = usersData.total || 0;
      const activeCount = usersData.data ? usersData.data.filter(u => u.status === 'active').length : 0;
      document.getElementById('activeUsers').textContent = activeCount;
    }
    
    if (postsData.success) {
      document.getElementById('totalPosts').textContent = postsData.total || 0;
      const pendingCount = postsData.data ? postsData.data.filter(p => p.status === 'pending').length : 0;
      document.getElementById('pendingPosts').textContent = pendingCount;
    }
  } catch (error) {
    console.error('Error loading dashboard:', error);
  }
}

/* =========================
   USERS
========================= */

async function loadUsers(page = 1) {
  try {
    currentPage.users = page;
    const offset = (page - 1) * ITEMS_PER_PAGE;
    
    const statusFilter = document.getElementById('userStatusFilter')?.value || '';
    const typeFilter = document.getElementById('userTypeFilter')?.value || '';
    const searchQuery = document.getElementById('userSearch')?.value || '';
    
    let url = `${API_BASE}/users?limit=${ITEMS_PER_PAGE}&offset=${offset}`;
    if (statusFilter) url += `&status=${statusFilter}`;
    if (typeFilter) url += `&type=${typeFilter}`;
    if (searchQuery) url += `&search=${searchQuery}`;
    
    const res = await fetch(url, {
      headers: { "x-admin-key": ADMIN_KEY }
    });

    const json = await res.json();
    if (!json.success) {
      console.error('Failed to load users:', json);
      return;
    }

    const tbody = document.getElementById("usersTable");
    tbody.innerHTML = "";

    if (!json.data || json.data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7" style="text-align: center; padding: 20px;">لا توجد بيانات</td></tr>';
      return;
    }

    json.data.forEach(u => {
  const statusBadge = getStatusBadge(u.status);
  const vip = Number(u.is_vip) === 1;

  tbody.innerHTML += `
    <tr>
      <td>${u.id}</td>
      <td>${u.name || '-'}</td>
      <td>${u.email || '-'}</td>
      <td>${u.phone || '-'}</td>  
      <td>${u.type || '-'}</td>
      <td>${statusBadge}</td>
      <td>${u.rating || '0.00'}</td>

      <!-- VIP -->
      <td style="text-align:center;">
        <button
          class="btn btn-sm"
          style="background:${vip ? '#f1c40f' : '#ecf0f1'}; color:${vip ? '#2c3e50' : '#7f8c8d'};"
          onclick="toggleVip(${u.id}, ${vip ? 1 : 0}, this)"
          title="Toggle VIP">
          ${vip ? '✅ VIP' : '☆ VIP'}
        </button>
      </td>

      <td>
        <button class="btn btn-sm" onclick="viewUserDetails(${u.id})" title="عرض">👁️</button>
        <button class="btn btn-primary" onclick="editUserModal(${u.id})">تعديل</button>
        <button class="btn btn-sm" onclick="banUser(${u.id})" title="حظر">⛔</button>
      </td>
    </tr>
  `;
});

    // Pagination
    const totalPages = Math.ceil((json.total || 0) / ITEMS_PER_PAGE);
    renderPagination('usersPagination', page, totalPages, 'loadUsers');
  } catch (error) {
    console.error('Error loading users:', error);
  }
}


window.toggleVip = async function (userId, currentVip, btnEl) {
  const nextVip = currentVip === 1 ? 0 : 1;

  // optimistic UI
  const oldHtml = btnEl.innerHTML;
  const oldStyle = btnEl.getAttribute("style") || "";

  btnEl.disabled = true;
  btnEl.innerHTML = "⏳";
  btnEl.setAttribute(
    "style",
    `background:${nextVip ? '#f1c40f' : '#ecf0f1'}; color:${nextVip ? '#2c3e50' : '#7f8c8d'};`
  );

  try {
    const res = await fetch(`${API_BASE}/users/${userId}/vip`, {
      method: "PATCH",
      headers: adminHeaders(),
      body: JSON.stringify({ is_vip: nextVip }),
    });

    // ✅ if server responded but not OK → error
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new Error(`HTTP ${res.status}: ${text}`);
    }

    // ✅ try json, but don't fail if it's not json
    let json = {};
    const ct = res.headers.get("content-type") || "";
    if (ct.includes("application/json")) {
      json = await res.json().catch(() => ({}));
    }

    // if API returns success=false, treat it as error
    if (json && json.success === false) {
      throw new Error(json.message || "API error");
    }

    // success
    btnEl.innerHTML = nextVip ? "✅ VIP" : "☆ VIP";
    btnEl.setAttribute("onclick", `toggleVip(${userId}, ${nextVip}, this)`);
  } catch (e) {
    console.error("VIP toggle error:", e);

    // rollback
    btnEl.innerHTML = oldHtml;
    btnEl.setAttribute("style", oldStyle);

    alert("Failed to update VIP");
  } finally {
    btnEl.disabled = false;
  }
};



function editUserModal(userId) {
  currentUserId = userId;
  // Fetch user data and populate edit form
  fetch(`${API_BASE}/users/${userId}`, {
    headers: { "x-admin-key": ADMIN_KEY }
  })
  .then(r => r.json())
  .then(json => {
    if (json.success && json.data) {
      const user = json.data;
      document.getElementById('editUserName').value = user.name || '';
      document.getElementById('editUserType').value = user.type || 'player';
      document.getElementById('editUserStatus').value = user.status || 'pending';
      openModal('editUserModal');
    }
  })
  .catch(err => console.error('Error:', err));
}

async function saveUserEdit() {
  try {
    const response = await fetch(`${API_BASE}/users/${currentUserId}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "x-admin-key": ADMIN_KEY
      },
      body: JSON.stringify({
        name: document.getElementById('editUserName').value,
        status: document.getElementById('editUserStatus').value,
        type: document.getElementById('editUserType').value
      })
    });

    const json = await response.json();
    if (json.success) {
      alert('تم تحديث المستخدم بنجاح');
      closeModal('editUserModal');
      loadUsers(currentPage.users);
    } else {
      alert('فشل التحديث: ' + (json.message || 'خطأ غير معروف'));
    }
  } catch (error) {
    console.error('Error saving user:', error);
    alert('حدث خطأ في الحفظ');
  }
}

async function banUser(id) {
  if (!id || id === 'null' || id === null) {
    console.error('banUser called with invalid id:', id);
    alert('معرف المستخدم غير صحيح');
    return;
  }

  if (!confirm("هل تريد حظر هذا المستخدم؟")) return;

  try {
    const response = await fetch(`${API_BASE}/users/${id}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "x-admin-key": ADMIN_KEY
      },
      body: JSON.stringify({ status: 'pending' })
    });

    const json = await response.json();
    if (json.success) {
      alert('تم حظر المستخدم');
      loadUsers(currentPage.users);
    }
  } catch (error) {
    console.error('Error banning user:', error);
  }
}

/* =========================
   POSTS
========================= */

async function loadPosts(page = 1) {
  try {
    currentPage.posts = page;
    const offset = (page - 1) * ITEMS_PER_PAGE;
    
    const statusFilter = document.getElementById('postStatusFilter')?.value || '';
    
    let url = `${API_BASE}/posts?limit=${ITEMS_PER_PAGE}&offset=${offset}`;
    if (statusFilter) url += `&status=${statusFilter}`;
    
    const res = await fetch(url, {
      headers: { "x-admin-key": ADMIN_KEY }
    });

    const json = await res.json();
    if (!json.success) {
      console.error('Failed to load posts:', json);
      return;
    }

    const tbody = document.getElementById("postsTable");
    tbody.innerHTML = "";

    if (!json.data || json.data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7" style="text-align: center; padding: 20px;">لا توجد بيانات</td></tr>';
      return;
    }

    json.data.forEach(p => {
      const statusBadge = getStatusBadge(p.status);
      const caption = (p.caption || '').substring(0, 50) + (p.caption && p.caption.length > 50 ? '...' : '');
      
      tbody.innerHTML += `
        <tr>
          <td>${p.id}</td>
          <td>${p.user_name || '-'}</td>
          <td>${caption || '-'}</td>
          <td>${statusBadge}</td>
          <td>${p.views || 0}</td>
          <td>${p.comment_count || 0}</td>
          <td>
            <button class="btn btn-sm" onclick="viewPostDetails(${p.id})" title="عرض">👁️</button>
            <button class="btn btn-sm" onclick="approvePost(${p.id})" title="موافقة">✓</button>
            <button class="btn btn-sm" onclick="rejectPost(${p.id})" title="رفض">✗</button>
            <button class="btn btn-sm" onclick="deletePost(${p.id})" title="حذف">🗑️</button>
          </td>
        </tr>
      `;
    });

    // Pagination
    const totalPages = Math.ceil((json.total || 0) / ITEMS_PER_PAGE);
    renderPagination('postsPagination', page, totalPages, 'loadPosts');
  } catch (error) {
    console.error('Error loading posts:', error);
  }
}

async function viewPostDetails(postId) {
  try {
    const res = await fetch(`${API_BASE}/posts/${postId}`, {
      headers: { "x-admin-key": ADMIN_KEY }
    });

    const json = await res.json();
    if (!json.success || !json.data) {
      alert('فشل تحميل بيانات المنشور');
      return;
    }

    const post = json.data;
    currentPostId = postId;

    // Populate modal
    document.getElementById('postDetailId').textContent = post.id || '-';
    document.getElementById('postDetailUser').textContent = post.user_name || '-';
    document.getElementById('postDetailMediaType').textContent = post.media_type || '-';
    document.getElementById('postDetailStatus').textContent = post.status || '-';
    document.getElementById('postDetailViews').textContent = post.views || 0;
    document.getElementById('postDetailComments').textContent = post.comment_count || 0;
    document.getElementById('postDetailPinned').textContent = post.is_pinned ? 'نعم' : 'لا';
    document.getElementById('postDetailHidden').textContent = post.is_hidden ? 'نعم' : 'لا';
    document.getElementById('postDetailCaption').textContent = post.caption || 'لا يوجد وصف';

    // Handle media display
    const mediaContainer = document.getElementById('postDetailMediaContainer');
    const imgElement = document.getElementById('postDetailImage');
    const videoElement = document.getElementById('postDetailVideo');
    const noMediaSpan = document.getElementById('postDetailNoMedia');

    imgElement.style.display = 'none';
    videoElement.style.display = 'none';
    noMediaSpan.style.display = 'none';

    if (post.media_url) {
      if (post.media_type === 'image' || post.media_url.match(/\.(jpg|jpeg|png|gif|webp)$/i)) {
        imgElement.src = post.media_url;
        imgElement.style.display = 'block';
      } else if (post.media_type === 'video' || post.media_url.match(/\.(mp4|webm|ogg)$/i)) {
        videoElement.src = post.media_url;
        videoElement.style.display = 'block';
      } else {
        noMediaSpan.textContent = 'نوع وسائط غير مدعوم';
        noMediaSpan.style.display = 'block';
      }
    } else {
      noMediaSpan.style.display = 'block';
    }

    openModal('postDetailModal');
  } catch (error) {
    console.error('Error loading post details:', error);
    alert('حدث خطأ في تحميل البيانات');
  }
}

async function approvePost(id) {
  try {
    const response = await fetch(`${API_BASE}/posts/${id}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "x-admin-key": ADMIN_KEY
      },
      body: JSON.stringify({ status: 'active' })
    });

    const json = await response.json();
    if (json.success) {
      alert('تم الموافقة على المنشور');
      loadPosts(currentPage.posts);
      closeModal('postDetailModal');
    }
  } catch (error) {
    console.error('Error approving post:', error);
  }
}

async function rejectPost(id) {
  try {
    const response = await fetch(`${API_BASE}/posts/${id}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "x-admin-key": ADMIN_KEY
      },
      body: JSON.stringify({ status: 'pending' })
    });

    const json = await response.json();
    if (json.success) {
      alert('تم رفض المنشور');
      loadPosts(currentPage.posts);
      closeModal('postDetailModal');
    }
  } catch (error) {
    console.error('Error rejecting post:', error);
  }
}

async function deletePost(id) {
  if (!confirm("هل تريد حذف هذا المنشور؟")) return;

  try {
    const response = await fetch(`${API_BASE}/posts/${id}`, {
      method: "DELETE",
      headers: { "x-admin-key": ADMIN_KEY }
    });

    const json = await response.json();
    if (json.success) {
      alert('تم حذف المنشور');
      loadPosts(currentPage.posts);
      closeModal('postDetailModal');
    }
  } catch (error) {
    console.error('Error deleting post:', error);
  }
}

/* =========================
   COMMENTS
========================= */

async function loadComments(page = 1) {
  try {
    currentPage.comments = page;
    const offset = (page - 1) * ITEMS_PER_PAGE;
    
    const res = await fetch(`${API_BASE}/comments?limit=${ITEMS_PER_PAGE}&offset=${offset}`, {
      headers: { "x-admin-key": ADMIN_KEY }
    });

    const json = await res.json();
    if (!json.success) return;

    const tbody = document.getElementById("commentsTable");
    tbody.innerHTML = "";

    if (!json.data || json.data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" style="text-align: center; padding: 20px;">لا توجد بيانات</td></tr>';
      return;
    }

    json.data.forEach(c => {
      const comment = (c.content || '').substring(0, 50) + (c.content && c.content.length > 50 ? '...' : '');
      tbody.innerHTML += `
        <tr>
          <td>${c.id}</td>
          <td>${c.user_name || '-'}</td>
          <td>${comment || '-'}</td>
          <td>${c.status || '-'}</td>
          <td>
            <button class="btn btn-sm" onclick="approveComment(${c.id})">✓</button>
            <button class="btn btn-sm" onclick="deleteComment(${c.id})">🗑️</button>
          </td>
        </tr>
      `;
    });

    const totalPages = Math.ceil((json.total || 0) / ITEMS_PER_PAGE);
    renderPagination('commentsPagination', page, totalPages, 'loadComments');
  } catch (error) {
    console.error('Error loading comments:', error);
  }
}

async function approveComment(id) {
  try {
    await fetch(`${API_BASE}/comments/${id}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "x-admin-key": ADMIN_KEY
      },
      body: JSON.stringify({ status: 'active' })
    });
    loadComments(currentPage.comments);
  } catch (error) {
    console.error('Error approving comment:', error);
  }
}

async function deleteComment(id) {
  if (!confirm("حذف التعليق؟")) return;
  try {
    await fetch(`${API_BASE}/comments/${id}`, {
      method: "DELETE",
      headers: { "x-admin-key": ADMIN_KEY }
    });
    loadComments(currentPage.comments);
  } catch (error) {
    console.error('Error deleting comment:', error);
  }
}

/* =========================
   REPORTS
========================= */

async function loadReports(page = 1) {
  try {
    currentPage.reports = page;
    const offset = (page - 1) * ITEMS_PER_PAGE;
    
    const res = await fetch(`${API_BASE}/reports?limit=${ITEMS_PER_PAGE}&offset=${offset}`, {
      headers: { "x-admin-key": ADMIN_KEY }
    });

    const json = await res.json();
    if (!json.success) return;

    const tbody = document.getElementById("reportsTable");
    tbody.innerHTML = "";

    if (!json.data || json.data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" style="text-align: center; padding: 20px;">لا توجد بيانات</td></tr>';
      return;
    }

    json.data.forEach(r => {
      const reason = (r.reason || '').substring(0, 40) + (r.reason && r.reason.length > 40 ? '...' : '');
      tbody.innerHTML += `
        <tr>
          <td>${r.id}</td>
          <td>${r.reporter_name || '-'}</td>
          <td>${reason || '-'}</td>
          <td>${r.status || '-'}</td>
          <td>
            <button class="btn btn-sm" onclick="resolveReport(${r.id})">✓</button>
            <button class="btn btn-sm" onclick="deleteReport(${r.id})">🗑️</button>
          </td>
        </tr>
      `;
    });

    const totalPages = Math.ceil((json.total || 0) / ITEMS_PER_PAGE);
    renderPagination('reportsPagination', page, totalPages, 'loadReports');
  } catch (error) {
    console.error('Error loading reports:', error);
  }
}

async function resolveReport(id) {
  try {
    await fetch(`${API_BASE}/reports/${id}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "x-admin-key": ADMIN_KEY
      },
      body: JSON.stringify({ status: 'resolved' })
    });
    loadReports(currentPage.reports);
  } catch (error) {
    console.error('Error resolving report:', error);
  }
}

async function deleteReport(id) {
  if (!confirm("حذف التقرير؟")) return;
  try {
    await fetch(`${API_BASE}/reports/${id}`, {
      method: "DELETE",
      headers: { "x-admin-key": ADMIN_KEY }
    });
    loadReports(currentPage.reports);
  } catch (error) {
    console.error('Error deleting report:', error);
  }
}

/* =========================
   AUDIT LOGS
========================= */

async function loadAuditLogs(page = 1) {
  try {
    currentPage.audit = page;
    const offset = (page - 1) * ITEMS_PER_PAGE;
    
    const res = await fetch(`${API_BASE}/audit?limit=${ITEMS_PER_PAGE}&offset=${offset}`, {
      headers: { "x-admin-key": ADMIN_KEY }
    });

    const json = await res.json();
    if (!json.success) return;

    const tbody = document.getElementById("auditTable");
    tbody.innerHTML = "";

    if (!json.data || json.data.length === 0) {
      tbody.innerHTML = '<tr><td colspan="4" style="text-align: center; padding: 20px;">لا توجد بيانات</td></tr>';
      return;
    }

    json.data.forEach(log => {
      tbody.innerHTML += `
        <tr>
          <td>${log.id}</td>
          <td>${log.admin_name || '-'}</td>
          <td>${log.action || '-'}</td>
          <td>${formatDate(log.created_at)} ${formatTime(log.created_at)}</td>
        </tr>
      `;
    });

    const totalPages = Math.ceil((json.total || 0) / ITEMS_PER_PAGE);
    renderPagination('auditPagination', page, totalPages, 'loadAuditLogs');
  } catch (error) {
    console.error('Error loading audit logs:', error);
  }
}

/* =========================
   PAGINATION
========================= */

function renderPagination(containerId, currentPage, totalPages, loadFunction) {
  const container = document.getElementById(containerId);
  if (!container) return;

  container.innerHTML = "";

  if (totalPages <= 1) return;

  // Previous button
  if (currentPage > 1) {
    const prevBtn = document.createElement('button');
    prevBtn.style.padding = '8px 12px';
    prevBtn.style.border = '1px solid #bdc3c7';
    prevBtn.style.background = 'white';
    prevBtn.style.cursor = 'pointer';
    prevBtn.style.borderRadius = '4px';
    prevBtn.style.color = '#333';
    prevBtn.style.fontSize = '14px';
    prevBtn.textContent = '← السابق';
    prevBtn.onclick = () => window[loadFunction](currentPage - 1);
    container.appendChild(prevBtn);
  }

  // Page numbers
  for (let i = Math.max(1, currentPage - 2); i <= Math.min(totalPages, currentPage + 2); i++) {
    const btn = document.createElement('button');
    btn.style.padding = '8px 12px';
    btn.style.border = '1px solid #bdc3c7';
    btn.style.cursor = 'pointer';
    btn.style.borderRadius = '4px';
    btn.style.fontSize = '14px';
    btn.style.fontWeight = '600';
    btn.style.minWidth = '36px';
    
    if (i === currentPage) {
      btn.style.background = '#667eea';
      btn.style.color = 'white';
      btn.style.borderColor = '#667eea';
    } else {
      btn.style.background = 'white';
      btn.style.color = '#333';
    }
    
    btn.textContent = i;
    btn.onclick = () => window[loadFunction](i);
    container.appendChild(btn);
  }

  // Next button
  if (currentPage < totalPages) {
    const nextBtn = document.createElement('button');
    nextBtn.style.padding = '8px 12px';
    nextBtn.style.border = '1px solid #bdc3c7';
    nextBtn.style.background = 'white';
    nextBtn.style.cursor = 'pointer';
    nextBtn.style.borderRadius = '4px';
    nextBtn.style.color = '#333';
    nextBtn.style.fontSize = '14px';
    nextBtn.textContent = 'التالي →';
    nextBtn.onclick = () => window[loadFunction](currentPage + 1);
    container.appendChild(nextBtn);
  }
}

function escapeHtml(s){
  return (s || '')
    .replaceAll('&','&amp;')
    .replaceAll('<','&lt;')
    .replaceAll('>','&gt;')
    .replaceAll('"','&quot;');
}

async function loadAds() {
  try {
    // Admin ads are served from /api/ads/admin/ads
    const res = await fetch(`${ADS_API_BASE}/admin/ads`, {
      headers: { "x-admin-key": ADMIN_KEY }
    });

    const tbody = document.getElementById("adsTable");
    if (!tbody) return;
    tbody.innerHTML = "";

    // Attempt to parse JSON, and handle HTML/error responses
    let json = null;
    try {
      json = await res.json();
    } catch (parseError) {
      console.error('loadAds: invalid JSON', parseError);
      tbody.innerHTML = `<tr><td colspan="5">خطأ في استجابة الخادم</td></tr>`;
      return;
    }

    if (!res.ok || !json || !json.success || !json.data) {
      tbody.innerHTML = `<tr><td colspan="5">فشل التحميل</td></tr>`;
      return;
    }

    json.data.sort((a, b) => (a.slot || 0) - (b.slot || 0));

    json.data.forEach(a => {
      const slot = a.slot;
      const imgHtml = a.imageUrl
        ? `<img src="${a.imageUrl}" class="media-preview" style="width:90px;height:90px;object-fit:cover;border-radius:8px;" />`
        : `<span style="color:#999">Default</span>`;

      tbody.innerHTML += `
        <tr>
          <td>${slot}</td>
          <td><input style="width:100%" id="ad_title_${slot}" value="${escapeHtml(a.title || '')}" /></td>
          <td><input style="width:100%" id="ad_sub_${slot}" value="${escapeHtml(a.subtitle || '')}" /></td>
          <td>
            ${imgHtml}
            <div style="margin-top:8px">
              <input type="file" id="ad_file_${slot}" accept="image/*" />
            </div>
          </td>
          <td style="display:flex; gap:8px; flex-wrap:wrap;">
            <button class="btn btn-primary" onclick="saveAd(${slot})">💾 حفظ</button>
            <button class="btn btn-warning" onclick="uploadAdImage(${slot})">⬆️ رفع</button>
            <button class="btn btn-danger" onclick="removeAdImage(${slot})">🗑️ حذف الصورة</button>
          </td>
        </tr>
      `;
    });

  } catch (e) {
    console.error(e);
    alert("حدث خطأ في تحميل الإعلانات");
  }
}

async function saveAd(slot) {
  const title = document.getElementById(`ad_title_${slot}`)?.value || '';
  const subtitle = document.getElementById(`ad_sub_${slot}`)?.value || '';

  const res = await fetch(`${ADS_API_BASE}/admin/ads/${slot}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json", "x-admin-key": ADMIN_KEY },
    body: JSON.stringify({ title, subtitle })
  });

  const json = await res.json();
  if (json.success) alert("تم حفظ الإعلان");
  else alert(json.message || "فشل الحفظ");

  loadAds();
}

async function uploadAdImage(slot) {
  const input = document.getElementById(`ad_file_${slot}`);
  if (!input || !input.files || input.files.length === 0) {
    alert("اختر صورة أولاً");
    return;
  }

  const fd = new FormData();
  fd.append("image", input.files[0]);

  const res = await fetch(`${ADS_API_BASE}/admin/ads/${slot}/image`, {
 	method: "POST",
  	headers: { "x-admin-key": ADMIN_KEY },
  	body: fd
  });

  const json = await res.json();
  if (json.success) alert("تم رفع الصورة");
  else alert(json.message || "فشل رفع الصورة");

  loadAds();
}

async function removeAdImage(slot) {
  const res = await fetch(`${ADS_API_BASE}/admin/ads/${slot}/image`, {
    method: "DELETE",
    headers: { "x-admin-key": ADMIN_KEY }
  });

  const json = await res.json();
  if (json.success) alert("تم حذف الصورة (رجع للـ Default)");
  else alert(json.message || "فشل الحذف");

  loadAds();
}

/* =========================
   INITIALIZATION
========================= */

document.addEventListener("DOMContentLoaded", () => {
  // Set up event listeners
  const editUserForm = document.getElementById('editUserForm');
  if (editUserForm) {
    editUserForm.addEventListener('submit', (e) => {
      e.preventDefault();
      saveUserEdit();
    });
  }

  // Close modals when clicking outside
window.onclick = (event) => {
  if (event.target.classList.contains('modal')) {
    event.target.classList.remove('show'); // ✅ same as closeModal()
  }
};

  const changePasswordForm = document.getElementById("changePasswordForm");
if (changePasswordForm) {
  changePasswordForm.addEventListener("submit", async (e) => {
    e.preventDefault();

    const p1 = document.getElementById("cp_newPass").value || "";
    const p2 = document.getElementById("cp_confirmPass").value || "";

    if (p1.length < 6) return alert("كلمة المرور يجب أن تكون 6 أحرف على الأقل");
    if (p1 !== p2) return alert("كلمتا المرور غير متطابقتين");
    if (!currentPasswordUserId) return alert("UserId غير صالح");

    try {
      const res = await fetch(`${API_BASE}/users/${currentPasswordUserId}/password`, {
        method: "PATCH",
        headers: adminHeaders(),
        body: JSON.stringify({ new_password: p1 }),
      });

      const json = await res.json().catch(() => ({}));

      if (!res.ok || json.success === false) {
        return alert(json.message || `فشل تغيير كلمة المرور (HTTP ${res.status})`);
      }

      alert("✅ تم تغيير كلمة المرور بنجاح");
      closeModal("changePasswordModal");
    } catch (err) {
      console.error(err);
      alert("حدث خطأ");
    }
  });
}

  // Load initial dashboard
  loadDashboard();
});