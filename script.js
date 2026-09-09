const CACHE_KEY = 'pme_companies';

function getCompaniesFromCache() {
  const raw = localStorage.getItem(CACHE_KEY);

  if (!raw) {
    return [];
  }

  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function saveCompaniesToCache(companies) {
  localStorage.setItem(CACHE_KEY, JSON.stringify(companies));
}

function renderCompanies() {
  const list = document.getElementById('company-list');
  const companies = getCompaniesFromCache();

  list.innerHTML = '';

  companies.forEach((company) => {
    const item = document.createElement('li');
    item.textContent = `${company.nome} • CNPJ: ${company.cnpj} • ${company.email}`;
    list.appendChild(item);
  });
}

function registerCompany(event) {
  event.preventDefault();

  const form = event.currentTarget;
  const formData = new FormData(form);

  const company = {
    nome: String(formData.get('nome') || '').trim(),
    cnpj: String(formData.get('cnpj') || '').trim(),
    email: String(formData.get('email') || '').trim()
  };

  if (!company.nome || !company.cnpj || !company.email) {
    return;
  }

  const companies = getCompaniesFromCache();
  companies.push(company);

  saveCompaniesToCache(companies);
  form.reset();
  renderCompanies();
}

document.getElementById('company-form').addEventListener('submit', registerCompany);
renderCompanies();
