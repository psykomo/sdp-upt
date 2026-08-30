-- Add 20 synthetic UPT 001 identitas to sdp_pusat (shared_database national sim).
-- Keeps existing 093 rows — for cross-UPT row-scope testing.
-- Run: docker exec -i sdp-mariadb mariadb -usdp -psdp_local sdp_pusat < scripts/sql/seed-sdp_pusat-identitas-001-20.sql

SET FOREIGN_KEY_CHECKS = 0;

DELETE FROM kejahatan WHERE ID_PERKARA IN (
  SELECT ID_PERKARA FROM perkara WHERE NOMOR_INDUK LIKE '00120260829%'
);
DELETE FROM sidik_jari WHERE NOMOR_INDUK LIKE '00120260829%';
DELETE FROM usertbl WHERE dbid LIKE '00120260829%';
DELETE FROM identitas_mirip WHERE NOMOR_INDUK_1 LIKE '00120260829%' OR NOMOR_INDUK_2 LIKE '00120260829%';
DELETE FROM log_file WHERE NOMOR_INDUK LIKE '00120260829%';
DELETE FROM log_biometric WHERE NOMOR_INDUK LIKE '00120260829%';
DELETE FROM identitas_attribute_histori WHERE NOMOR_INDUK LIKE '00120260829%';
DELETE FROM perkara WHERE NOMOR_INDUK LIKE '00120260829%';
DELETE FROM identitas WHERE NOMOR_INDUK LIKE '00120260829%';

SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO identitas (
  NOMOR_INDUK, NAMA_LENGKAP, ID_JENIS_KELAMIN, ID_JENIS_WARGANEGARA, ID_JENIS_AGAMA,
  TANGGAL_LAHIR, ALAMAT, NM_AYAH, NM_IBU, JML_ANAK, NOMOR_INDUK_NASIONAL,
  IS_DELETED, IS_WBP_BERESIKO_TINGGI, IS_PENGARUH_TERHADAP_MASYARAKAT, IS_VERIFIKASI, KONSOLIDASI
) VALUES
('001202608290001', 'Sim Banda Aceh 01', 'L', 'WNI', 'ISM', '1990-03-12', 'Jl Merdeka No 1, Banda Aceh', 'Ayah Sim 01', 'Ibu Sim 01', 0, '', 0, 0, 0, 0, 0),
('001202608290002', 'Sim Banda Aceh 02', 'P', 'WNI', 'ISM', '1991-04-13', 'Jl Merdeka No 2, Banda Aceh', 'Ayah Sim 02', 'Ibu Sim 02', 1, '', 0, 0, 0, 0, 0),
('001202608290003', 'Sim Banda Aceh 03', 'L', 'WNI', 'ISM', '1992-05-14', 'Jl Merdeka No 3, Banda Aceh', 'Ayah Sim 03', 'Ibu Sim 03', 0, '', 0, 0, 0, 0, 0),
('001202608290004', 'Sim Banda Aceh 04', 'L', 'WNI', 'ISM', '1993-06-15', 'Jl Merdeka No 4, Banda Aceh', 'Ayah Sim 04', 'Ibu Sim 04', 2, '', 0, 0, 0, 0, 0),
('001202608290005', 'Sim Banda Aceh 05', 'P', 'WNI', 'ISM', '1994-07-16', 'Jl Merdeka No 5, Banda Aceh', 'Ayah Sim 05', 'Ibu Sim 05', 0, '', 0, 0, 0, 0, 0),
('001202608290006', 'Sim Banda Aceh 06', 'L', 'WNI', 'ISM', '1995-08-17', 'Jl Merdeka No 6, Banda Aceh', 'Ayah Sim 06', 'Ibu Sim 06', 1, '', 0, 0, 0, 0, 0),
('001202608290007', 'Sim Banda Aceh 07', 'L', 'WNI', 'ISM', '1996-09-18', 'Jl Merdeka No 7, Banda Aceh', 'Ayah Sim 07', 'Ibu Sim 07', 0, '', 0, 0, 0, 0, 0),
('001202608290008', 'Sim Banda Aceh 08', 'P', 'WNI', 'ISM', '1997-10-19', 'Jl Merdeka No 8, Banda Aceh', 'Ayah Sim 08', 'Ibu Sim 08', 3, '', 0, 0, 0, 0, 0),
('001202608290009', 'Sim Banda Aceh 09', 'L', 'WNI', 'ISM', '1998-11-20', 'Jl Merdeka No 9, Banda Aceh', 'Ayah Sim 09', 'Ibu Sim 09', 0, '', 0, 0, 0, 0, 0),
('001202608290010', 'Sim Banda Aceh 10', 'L', 'WNI', 'ISM', '1999-12-21', 'Jl Merdeka No 10, Banda Aceh', 'Ayah Sim 10', 'Ibu Sim 10', 1, '', 0, 0, 0, 0, 0),
('001202608290011', 'Sim Banda Aceh 11', 'P', 'WNI', 'ISM', '2000-01-22', 'Jl Merdeka No 11, Banda Aceh', 'Ayah Sim 11', 'Ibu Sim 11', 0, '', 0, 0, 0, 0, 0),
('001202608290012', 'Sim Banda Aceh 12', 'L', 'WNI', 'ISM', '2001-02-23', 'Jl Merdeka No 12, Banda Aceh', 'Ayah Sim 12', 'Ibu Sim 12', 2, '', 0, 0, 0, 0, 0),
('001202608290013', 'Sim Banda Aceh 13', 'L', 'WNI', 'ISM', '2002-03-24', 'Jl Merdeka No 13, Banda Aceh', 'Ayah Sim 13', 'Ibu Sim 13', 0, '', 0, 0, 0, 0, 0),
('001202608290014', 'Sim Banda Aceh 14', 'P', 'WNI', 'ISM', '2003-04-25', 'Jl Merdeka No 14, Banda Aceh', 'Ayah Sim 14', 'Ibu Sim 14', 1, '', 0, 0, 0, 0, 0),
('001202608290015', 'Sim Banda Aceh 15', 'L', 'WNI', 'ISM', '2004-05-26', 'Jl Merdeka No 15, Banda Aceh', 'Ayah Sim 15', 'Ibu Sim 15', 0, '', 0, 0, 0, 0, 0),
('001202608290016', 'Sim Banda Aceh 16', 'L', 'WNI', 'ISM', '2005-06-27', 'Jl Merdeka No 16, Banda Aceh', 'Ayah Sim 16', 'Ibu Sim 16', 4, '', 0, 0, 0, 0, 0),
('001202608290017', 'Sim Banda Aceh 17', 'P', 'WNI', 'ISM', '2006-07-28', 'Jl Merdeka No 17, Banda Aceh', 'Ayah Sim 17', 'Ibu Sim 17', 0, '', 0, 0, 0, 0, 0),
('001202608290018', 'Sim Banda Aceh 18', 'L', 'WNI', 'ISM', '2007-08-29', 'Jl Merdeka No 18, Banda Aceh', 'Ayah Sim 18', 'Ibu Sim 18', 1, '', 0, 0, 0, 0, 0),
('001202608290019', 'Sim Banda Aceh 19', 'L', 'WNI', 'ISM', '2008-09-30', 'Jl Merdeka No 19, Banda Aceh', 'Ayah Sim 19', 'Ibu Sim 19', 0, '', 0, 0, 0, 0, 0),
('001202608290020', 'Sim Banda Aceh 20', 'P', 'WNI', 'ISM', '2009-10-01', 'Jl Merdeka No 20, Banda Aceh', 'Ayah Sim 20', 'Ibu Sim 20', 2, '', 0, 0, 0, 0, 0);

INSERT INTO perkara (
  ID_PERKARA, ID_PERKARA_PARENT, ID_STATUS, ID_SUB_STATUS, ID_UPT, ID_REG, IS_TAHANAN,
  IS_DENDA_LUNAS, ID_USER, NOMOR_INDUK, NMR_REG_GOL, TGL_MSK_LAPAS, TGL_PERTAMA_DITAHAN,
  TGL_EKSPIRASI_AWAL, TGL_EKSPIRASI, LOKASI_SEL, IS_DELETE, KONSOLIDASI, TGL_ENTRY
) VALUES
('001202608290001', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290001', 'BI.SIM/000001', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290002', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290002', 'BI.SIM/000002', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290003', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290003', 'BI.SIM/000003', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290004', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290004', 'BI.SIM/000004', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290005', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290005', 'BI.SIM/000005', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290006', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290006', 'BI.SIM/000006', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290007', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290007', 'BI.SIM/000007', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290008', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290008', 'BI.SIM/000008', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290009', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290009', 'BI.SIM/000009', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290010', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290010', 'BI.SIM/000010', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290011', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290011', 'BI.SIM/000011', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290012', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290012', 'BI.SIM/000012', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290013', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290013', 'BI.SIM/000013', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290014', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290014', 'BI.SIM/000014', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290015', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290015', 'BI.SIM/000015', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290016', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290016', 'BI.SIM/000016', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290017', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290017', 'BI.SIM/000017', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290018', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290018', 'BI.SIM/000018', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290019', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290019', 'BI.SIM/000019', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00'),
('001202608290020', NULL, 'STA', 'SSA1', '001', 'BI', 0, 0, 'admin', '001202608290020', 'BI.SIM/000020', '2026-08-01', '2026-07-01', '2028-08-01', '2028-08-01', '01', 0, 0, '2026-08-01 00:00:00');

SELECT 'identitas total' AS k, COUNT(*) AS n FROM identitas WHERE IS_DELETED=0 OR IS_DELETED IS NULL;
SELECT 'STA upt 001' AS k, COUNT(DISTINCT i.NOMOR_INDUK) AS n
  FROM identitas i JOIN perkara p ON p.NOMOR_INDUK=i.NOMOR_INDUK AND p.IS_DELETE=0 AND p.ID_STATUS='STA' AND p.ID_UPT='001'
  WHERE i.IS_DELETED=0 OR i.IS_DELETED IS NULL;
SELECT 'STA upt 093' AS k, COUNT(DISTINCT i.NOMOR_INDUK) AS n
  FROM identitas i JOIN perkara p ON p.NOMOR_INDUK=i.NOMOR_INDUK AND p.IS_DELETE=0 AND p.ID_STATUS='STA' AND p.ID_UPT='093'
  WHERE i.IS_DELETED=0 OR i.IS_DELETED IS NULL;
